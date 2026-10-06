import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/app_dependencies.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/network/network_status.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/storage/shared_files.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/sync_engine.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/customers/data/repositories/drift_customers_repository.dart';
import 'package:salahly/features/jobs/data/repositories/drift_jobs_repository.dart';
import 'package:salahly/salahly_app.dart';

import 'balance_fixtures.dart';
import 'fake_sync_remote.dart';
import 'fixtures.dart';
import 'mocks.dart';

/// A network that is up until a test says otherwise.
class FakeNetworkStatus implements NetworkStatus {
  bool connected = true;
  final _changes = StreamController<bool>.broadcast(sync: true);

  @override
  Future<bool> isConnected() async => connected;

  @override
  Stream<bool> get changes => _changes.stream;

  void change({required bool connected}) {
    this.connected = connected;
    _changes.add(connected);
  }
}

/// The whole app signed in as an approved technician, with the real
/// screens, cubits and on-phone database (in memory) and fakes at the
/// edges: the server, other apps, the microphone and the contacts.
///
/// Records written through [jobs] and [customers] show on the screens.
class TechnicianApp {
  TechnicianApp() {
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.userChanges).thenAnswer((_) => Stream.value(user));
    when(() => account.cachedProfile(any())).thenAnswer((_) async => profile);
    when(
      () => account.fetchProfile(any()),
    ).thenAnswer((_) async => const Ok(profile));
    when(() => userData.claimFor(any())).thenAnswer((_) async {});
    when(
      catalog.fetchAreas,
    ).thenAnswer((_) async => const Ok(TestAreas.all));
    when(
      () => apps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
    when(() => apps.dial(any())).thenAnswer((_) async => true);
    when(() => apps.map(any())).thenAnswer((_) async => true);
    stubBalance(balance, consumer: false);
    when(requests.fetchNewRequests).thenAnswer((_) async => const Ok([]));
    when(requests.fetchMyServices).thenAnswer((_) async => const Ok([]));
    when(
      catalog.fetchCategories,
    ).thenAnswer((_) async => const Ok(TestCategories.all));
    when(
      () => requests.fetchRequest(any()),
    ).thenAnswer((_) async => const Ok(null));
  }

  static const user = AuthUser(id: 'user-1');
  static const profile = UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'محمود عبد الله',
    activeRole: UserRole.technician,
    technician: TechnicianProfile(
      verificationStatus: VerificationStatus.approved,
      jobCredits: 2,
    ),
  );

  /// Call once from `setUpAll` before using [TechnicianApp].
  static void registerFallbacks() {
    final phone = PhoneNumber.tryParse('01000000000')!;
    registerFallbackValue(phone);
    registerFallbackValue(UserRole.consumer);
    registerFallbackValue(TopupMethod.instapay);
  }

  final database = AppDatabase(NativeDatabase.memory());
  final changes = LocalChanges();
  final remote = FakeSyncRemote();
  final network = FakeNetworkStatus();
  final auth = MockAuthRepository();
  final account = MockAccountRepository();
  final userData = MockUserScopedData();
  final catalog = MockCatalogRepository();
  final apps = MockExternalApps();
  final speech = MockSpeechInput();
  final contacts = MockContactPicker();
  final photoPicker = MockPhotoPicker();

  /// The marketplace: no new requests unless a test stubs some.
  final requests = MockTechnicianRequestsRepository();

  /// The balance: no transfers or movements unless a test stubs some.
  final balance = MockBalanceRepository();
  final photos = LocalPhotoStore(Directory.systemTemp.createTempSync());
  final sharedFiles = SharedFiles(Directory.systemTemp.createTempSync());

  /// The repositories' clock, for recording things in the past. The
  /// screens read the real clock.
  DateTime now = DateTime.now();

  late final jobs = DriftJobsRepository(
    database: database,
    photos: photos,
    changes: changes,
    currentUserId: () => user.id,
    clock: () => now,
  );
  late final customers = DriftCustomersRepository(
    database: database,
    changes: changes,
    clock: () => now,
  );

  AppDependencies get dependencies => AppDependencies(
    authRepository: auth,
    accountRepository: account,
    catalogRepository: catalog,
    onboardingRepository: MockOnboardingRepository(),
    customersRepository: customers,
    jobsRepository: jobs,
    consumerRequestsRepository: MockConsumerRequestsRepository(),
    technicianRequestsRepository: requests,
    balanceRepository: balance,
    locationService: MockLocationService(),
    photoPicker: photoPicker,
    userData: userData,
    networkStatus: network,
    localChanges: changes,
    database: database,
    syncEngine: SyncEngine(database: database, remote: remote, photos: photos),
    externalApps: apps,
    speechInput: speech,
    contactPicker: contacts,
    sharedFiles: sharedFiles,
  );

  /// Pumps the app on a small phone and opens [location].
  Future<void> pump(
    WidgetTester tester, {
    String location = '/technician',
    Size surfaceSize = const Size(360, 690),
  }) async {
    tester.view
      ..physicalSize = surfaceSize * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SalahlyApp(dependencies: dependencies));
    await settle(tester);
    if (location != '/technician') {
      router(tester).go(location);
      await settle(tester);
    }
  }

  /// Unmounts the app and lets the database's closing stream queries
  /// finish, so no timer is left behind.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(database.close);
  }

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  /// Lets database queries finish and the screens catch up.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

/// A widget test with a fresh [TechnicianApp], cleaned up after [body].
/// Call [TechnicianApp.registerFallbacks] in `setUpAll` first.
void testTechnicianApp(
  String description,
  Future<void> Function(WidgetTester tester, TechnicianApp app) body,
) {
  testWidgets(description, (tester) async {
    final app = TechnicianApp();
    await body(tester, app);
    await app.dispose(tester);
  });
}
