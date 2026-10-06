import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/app_dependencies.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/storage/shared_files.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/sync_engine.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/salahly_app.dart';

import 'balance_fixtures.dart';
import 'fake_sync_remote.dart';
import 'fixtures.dart';
import 'mocks.dart';
import 'technician_app.dart';

/// The whole app signed in as a consumer, with the real screens and
/// cubits and fakes at the edges. The marketplace ([requests]) has no
/// requests or addresses unless a test stubs some, and 24 technicians in
/// every area.
class ConsumerApp {
  ConsumerApp({Honorific honorific = Honorific.ms, int requestCredits = 2})
    : profile = UserProfile(
        id: user.id,
        phone: '+201114567720',
        fullName: 'نورهان محمد',
        activeRole: UserRole.consumer,
        consumer: ConsumerProfile(
          honorific: honorific,
          areaId: 'nasr_city',
          areaName: 'مدينة نصر',
          requestCredits: requestCredits,
        ),
      ) {
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.userChanges).thenAnswer((_) => Stream.value(user));
    when(() => account.cachedProfile(any())).thenAnswer((_) async => profile);
    when(
      () => account.fetchProfile(any()),
    ).thenAnswer((_) async => Ok(profile));
    when(() => userData.claimFor(any())).thenAnswer((_) async {});
    when(
      catalog.fetchAreas,
    ).thenAnswer((_) async => const Ok(TestAreas.all));
    when(
      catalog.fetchCategories,
    ).thenAnswer((_) async => const Ok(TestCategories.all));
    stubBalance(balance);
    when(() => photoPicker.discard(any())).thenAnswer((_) async {});
    when(requests.fetchRequests).thenAnswer((_) async => const Ok([]));
    when(requests.fetchAddresses).thenAnswer((_) async => const Ok([]));
    when(
      () => requests.availableTechnicianCount(
        categoryId: any(named: 'categoryId'),
        areaId: any(named: 'areaId'),
      ),
    ).thenAnswer((_) async => const Ok(24));
    when(
      () => apps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
    when(() => apps.dial(any())).thenAnswer((_) async => true);
  }

  static const user = AuthUser(id: 'consumer-1');

  /// The signed-in consumer; [account] serves it until a test stubs
  /// another.
  final UserProfile profile;

  /// Call once from `setUpAll` before using [ConsumerApp].
  static void registerFallbacks() => TechnicianApp.registerFallbacks();

  final database = AppDatabase(NativeDatabase.memory());
  final auth = MockAuthRepository();
  final account = MockAccountRepository();
  final userData = MockUserScopedData();
  final catalog = MockCatalogRepository();
  final requests = MockConsumerRequestsRepository();

  /// The balance: no transfers or movements unless a test stubs some.
  final balance = MockBalanceRepository();
  final apps = MockExternalApps();
  final speech = MockSpeechInput();
  final photoPicker = MockPhotoPicker();
  final location = MockLocationService();
  final photos = LocalPhotoStore(Directory.systemTemp.createTempSync());

  AppDependencies get dependencies => AppDependencies(
    authRepository: auth,
    accountRepository: account,
    catalogRepository: catalog,
    onboardingRepository: MockOnboardingRepository(),
    customersRepository: MockCustomersRepository(),
    jobsRepository: MockJobsRepository(),
    consumerRequestsRepository: requests,
    technicianRequestsRepository: MockTechnicianRequestsRepository(),
    balanceRepository: balance,
    locationService: location,
    photoPicker: photoPicker,
    userData: userData,
    networkStatus: FakeNetworkStatus(),
    localChanges: LocalChanges(),
    database: database,
    syncEngine: SyncEngine(
      database: database,
      remote: FakeSyncRemote(),
      photos: photos,
    ),
    externalApps: apps,
    speechInput: speech,
    contactPicker: MockContactPicker(),
    sharedFiles: SharedFiles(Directory.systemTemp.createTempSync()),
  );

  /// Pumps the app on a small phone and opens [location].
  Future<void> pump(
    WidgetTester tester, {
    String location = '/consumer',
    Size surfaceSize = const Size(360, 690),
  }) async {
    tester.view
      ..physicalSize = surfaceSize * 3
      ..devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(SalahlyApp(dependencies: dependencies));
    await settle(tester);
    if (location != '/consumer') {
      router(tester).go(location);
      await settle(tester);
    }
  }

  /// Unmounts the app, stopping the screens' timers.
  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
    await tester.runAsync(database.close);
  }

  GoRouter router(WidgetTester tester) =>
      GoRouter.of(tester.element(find.byType(Navigator).first));

  /// Lets the fakes answer and the screens catch up.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
}

/// A widget test with a fresh [ConsumerApp], cleaned up after [body].
/// Call [ConsumerApp.registerFallbacks] in `setUpAll` first.
void testConsumerApp(
  String description,
  Future<void> Function(WidgetTester tester, ConsumerApp app) body, {
  ConsumerApp Function()? app,
}) {
  testWidgets(description, (tester) async {
    final consumer = app?.call() ?? ConsumerApp();
    await body(tester, consumer);
    await consumer.dispose(tester);
  });
}
