import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/live/live_updates.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:salahly/features/marketplace/presentation/cubit/open_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/open_requests_page.dart';

import '../../../../helpers/fake_live_updates.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

class _MockOpenRequestsCubit extends MockCubit<OpenRequestsState>
    implements OpenRequestsCubit {}

SessionReady _technician(VerificationStatus status) => SessionReady(
  user: const AuthUser(id: 'user-1'),
  profile: UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'محمود عبد الله',
    activeRole: UserRole.technician,
    technician: TechnicianProfile(verificationStatus: status, jobCredits: 3),
  ),
);

void main() {
  late _MockOpenRequestsCubit cubit;
  late MockAreasCubit areas;
  late MockCategoriesCubit categories;
  late MockSessionCubit session;
  late MockTechnicianRequestsRepository requests;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
  });

  setUp(() {
    cubit = _MockOpenRequestsCubit();
    areas = MockAreasCubit();
    categories = MockCategoriesCubit();
    session = MockSessionCubit();
    requests = MockTechnicianRequestsRepository();
    when(cubit.load).thenAnswer((_) async {});
    when(cubit.loadMore).thenAnswer((_) async {});
    when(() => cubit.selectCategory(any())).thenAnswer((_) async {});
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(() => categories.state).thenReturn(
      const CategoriesState(
        categories: [TestCategories.airConditioning, TestCategories.plumbing],
      ),
    );
  });

  void show(OpenRequestsState state) =>
      when(() => cubit.state).thenReturn(state);

  final live = FakeLiveUpdates();

  Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
    const OpenRequestsView(),
    repositories: [RepositoryProvider<LiveUpdates>.value(value: live)],
    blocs: [
      BlocProvider<OpenRequestsCubit>.value(value: cubit),
      BlocProvider<AreasCubit>.value(value: areas),
      BlocProvider<CategoriesCubit>.value(value: categories),
    ],
    stubRoutes: [AppRoutes.incomingRequest('request-1')],
  );

  Future<void> pumpPage(WidgetTester tester, VerificationStatus status) {
    when(() => session.state).thenReturn(_technician(status));
    when(
      () => requests.browseOpenRequests(
        categoryId: any(named: 'categoryId'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    return tester.pumpApp(
      const OpenRequestsPage(),
      repositories: [
        RepositoryProvider<TechnicianRequestsRepository>.value(
          value: requests,
        ),
        RepositoryProvider<LiveUpdates>.value(value: live),
      ],
      blocs: [
        BlocProvider<SessionCubit>.value(value: session),
        BlocProvider<AreasCubit>.value(value: areas),
        BlocProvider<CategoriesCubit>.value(value: categories),
      ],
    );
  }

  group('a technician whose ID is not approved', () {
    testWidgets('is told it is being reviewed, and asks for nothing', (
      tester,
    ) async {
      await pumpPage(tester, VerificationStatus.pending);

      expect(find.text(l10n.openRequestsTitle), findsOneWidget);
      expect(
        find.textContaining(l10n.techPendingTitle, findRichText: true),
        findsOneWidget,
      );
      expect(find.text(l10n.openRequestsLocked), findsOneWidget);
      verifyNever(
        () => requests.browseOpenRequests(
          categoryId: any(named: 'categoryId'),
          offset: any(named: 'offset'),
        ),
      );
    });

    testWidgets('is asked for new photos when the ID was rejected', (
      tester,
    ) async {
      await pumpPage(tester, VerificationStatus.rejected);

      expect(
        find.textContaining(l10n.techRejectedTitle, findRichText: true),
        findsOneWidget,
      );
      expect(find.text(l10n.openRequestsLocked), findsOneWidget);
    });
  });

  testWidgets('an approved technician gets the list', (tester) async {
    await pumpPage(tester, VerificationStatus.approved);
    await tester.pump();

    expect(find.text(l10n.openRequestsLocked), findsNothing);
    verify(
      () => requests.browseOpenRequests(
        categoryId: any(named: 'categoryId'),
        offset: any(named: 'offset'),
      ),
    ).called(1);
  });

  testWidgets('a new request fetches the list again at once', (tester) async {
    await pumpPage(tester, VerificationStatus.approved);
    await tester.pump();

    live.fire();
    await tester.pump();

    verify(
      () => requests.browseOpenRequests(
        categoryId: any(named: 'categoryId'),
        offset: any(named: 'offset'),
      ),
    ).called(2);
  });

  group('states', () {
    testWidgets('waits for the first page', (tester) async {
      show(const OpenRequestsState());
      await pumpView(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.openRequestsTitle), findsOneWidget);
    });

    testWidgets('says when nothing is open in his trades', (tester) async {
      show(const OpenRequestsState(status: OpenRequestsStatus.ready));
      await pumpView(tester);

      expect(find.text(l10n.openRequestsEmpty), findsOneWidget);
      expect(find.text(l10n.openRequestsEmptyHint), findsOneWidget);
    });

    testWidgets('says why the list could not be fetched, and tries again', (
      tester,
    ) async {
      show(
        const OpenRequestsState(
          status: OpenRequestsStatus.failed,
          failure: NetworkFailure(),
        ),
      );
      await pumpView(tester);

      await tester.tap(find.text(l10n.retry));

      verify(cubit.load).called(1);
    });

    testWidgets('says when the ID is not approved any more', (tester) async {
      show(
        const OpenRequestsState(
          status: OpenRequestsStatus.failed,
          failure: NotVerifiedFailure(),
        ),
      );
      await pumpView(tester);

      expect(find.text(l10n.retry), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('lists the requests and opens one', (tester) async {
      show(
        OpenRequestsState(
          status: OpenRequestsStatus.ready,
          requests: [testIncoming()],
        ),
      );
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('تكييف مش بيبرّد'), findsOneWidget);

      await tester.tap(find.text('تكييف مش بيبرّد'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.incomingRequest('request-1')), findsOneWidget);
    });

    testWidgets('picks a trade, or all of them', (tester) async {
      show(
        OpenRequestsState(
          status: OpenRequestsStatus.ready,
          categoryId: 'plumbing',
          requests: [testIncoming()],
        ),
      );
      await pumpView(tester);

      await tester.tap(find.text(TestCategories.airConditioning.name));
      verify(() => cubit.selectCategory('ac')).called(1);

      await tester.tap(find.text(l10n.directoryAll));
      verify(() => cubit.selectCategory(null)).called(1);
    });
  });
}
