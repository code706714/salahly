import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/pages/requests_page.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_filters.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../pump_app.dart';

void main() {
  late AdminHarness h;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    AdminHarness.registerFallbacks();
  });

  void stubRequests(Result<PagedResult<AdminRequest>> result) => when(
    () => h.requests.fetchRequests(
      any(),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => result);

  void stubComplaints(Result<PagedResult<AdminComplaint>> result) => when(
    () => h.requests.fetchComplaints(
      any(),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => result);

  setUp(() {
    h = AdminHarness();
    when(
      () => h.files.signedUrl(any(), any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    stubComplaints(const Ok(PagedResult(items: [], total: 0)));
  });

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const RequestsPage(),
    path: AdminRoutes.requests,
    size: const Size(1440, 1600),
    settle: settle,
  );

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  // The tab and the status pill read the same as the button.
  final resolveButton = find.widgetWithText(
    FilledButton,
    l10n.adminComplaintResolve,
  );

  Future<void> openComplaints(WidgetTester tester) async {
    await tester.tap(find.text(l10n.adminRequestsTabComplaints));
    await tester.pumpAndSettle();
  }

  group('requests', () {
    testWidgets('shows a spinner while they load', (tester) async {
      final pending = Completer<Result<PagedResult<AdminRequest>>>();
      when(
        () => h.requests.fetchRequests(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) => pending.future);

      await pump(tester, settle: false);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('says so when the filter matches nothing', (tester) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));

      await pump(tester);

      expect(find.text(l10n.adminRequestsEmpty), findsOneWidget);
    });

    testWidgets('says why they did not load and tries again', (tester) async {
      stubRequests(const Err(NetworkFailure()));
      await pump(tester);

      stubRequests(Ok(PagedResult(items: [testAdminRequest()], total: 1)));
      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();

      expect(find.text('R-1048'), findsOneWidget);
    });

    testWidgets('lists each request with its state', (tester) async {
      stubRequests(
        Ok(
          PagedResult(
            items: [
              testAdminRequest(),
              testAdminRequest(
                id: 'r2',
                status: AdminRequestStatus.done,
                technicianName: 'محمود السيد',
                stars: 4,
              ),
              testAdminRequest(
                id: 'r3',
                status: AdminRequestStatus.awaitingChoice,
                hasOpenComplaint: true,
              ),
            ],
            total: 142,
          ),
        ),
      );

      await pump(tester);

      expect(find.text(l10n.adminRequestsStatusNoOffers), findsOneWidget);
      expect(find.text(l10n.adminRequestsStatusDoneStars(4)), findsOneWidget);
      expect(find.text('محمود السيد'), findsOneWidget);
      expect(find.text(l10n.adminRequestsComplaintOpen), findsOneWidget);
      expect(find.text(l10n.adminRequestsTotal(3, 142)), findsOneWidget);
    });

    testWidgets('searches once typing pauses', (tester) async {
      stubRequests(Ok(PagedResult(items: [testAdminRequest()], total: 1)));
      await pump(tester);

      await tester.enterText(find.byType(TextField).first, '  R-1048 ');
      await tester.pump(AdminSearchField.debounce);
      await tester.pumpAndSettle();

      verify(
        () => h.requests.fetchRequests(
          const RequestFilter(search: 'R-1048'),
          limit: any(named: 'limit'),
          offset: 0,
        ),
      ).called(1);
    });
  });

  group('complaints', () {
    testWidgets('says nothing is open when the list is empty', (tester) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      await pump(tester);

      await openComplaints(tester);

      expect(find.text(l10n.adminComplaintsEmptyOpen), findsOneWidget);
    });

    testWidgets('shows what the customer wrote as plain text', (tester) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      stubComplaints(Ok(PagedResult(items: [testComplaint()], total: 1)));
      await pump(tester);

      await openComplaints(tester);

      expect(find.text('الفني ماجاش في الميعاد <b>وماردش</b>'), findsOneWidget);
      expect(find.text(l10n.adminComplaintReasonNoShow), findsOneWidget);
    });

    testWidgets('says so when a customer wrote no details', (tester) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      stubComplaints(
        Ok(PagedResult(items: [testComplaint(details: null)], total: 1)),
      );
      await pump(tester);

      await openComplaints(tester);

      expect(find.text(l10n.adminComplaintNoDetails), findsOneWidget);
    });

    testWidgets('shows a closed complaint with its note and no buttons', (
      tester,
    ) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      stubComplaints(
        Ok(
          PagedResult(
            items: [
              testComplaint(
                resolvedAt: adminNow,
                resolutionNote: 'كلمنا الفني',
              ),
            ],
            total: 1,
          ),
        ),
      );
      await pump(tester);

      await openComplaints(tester);

      expect(
        find.text(l10n.adminComplaintResolutionNote('كلمنا الفني')),
        findsOneWidget,
      );
      expect(resolveButton, findsNothing);
    });

    testWidgets('closes a complaint with a note', (tester) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      stubComplaints(Ok(PagedResult(items: [testComplaint()], total: 1)));
      when(
        () => h.requests.resolveComplaint(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
      await pump(tester);
      await openComplaints(tester);

      await tester.tap(resolveButton);
      await tester.pumpAndSettle();
      TextButton confirm() => tester.widget<TextButton>(
        find.ancestor(
          of: inDialog(l10n.adminComplaintResolveConfirm),
          matching: find.byType(TextButton),
        ),
      );
      expect(confirm().onPressed, isNull);

      await tester.enterText(find.byType(TextField).last, 'كلمنا الفني');
      await tester.pump();
      await tester.tap(inDialog(l10n.adminComplaintResolveConfirm));
      await tester.pumpAndSettle();

      verify(
        () => h.requests.resolveComplaint('complaint-1', 'كلمنا الفني'),
      ).called(1);
      expect(find.text(l10n.adminComplaintClosed), findsOneWidget);
    });

    testWidgets('does nothing when the admin backs out of the note', (
      tester,
    ) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      stubComplaints(Ok(PagedResult(items: [testComplaint()], total: 1)));
      await pump(tester);
      await openComplaints(tester);

      await tester.tap(resolveButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.adminCancel));
      await tester.pumpAndSettle();

      verifyNever(() => h.requests.resolveComplaint(any(), any()));
    });

    testWidgets('suspends the technician with a reason', (tester) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      stubComplaints(Ok(PagedResult(items: [testComplaint()], total: 1)));
      when(
        () => h.users.suspend(any(), any()),
      ).thenAnswer((_) async => const Ok(null));
      await pump(tester);
      await openComplaints(tester);

      await tester.tap(find.text(l10n.adminComplaintSuspend));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'شكاوي متكررة');
      await tester.pump();
      await tester.tap(inDialog(l10n.adminSuspendConfirm));
      await tester.pumpAndSettle();

      verify(() => h.users.suspend('tech-9', 'شكاوي متكررة')).called(1);
      expect(find.text(l10n.adminSuspended), findsOneWidget);
    });

    testWidgets('offers no suspension for a technician already suspended', (
      tester,
    ) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      stubComplaints(
        Ok(
          PagedResult(
            items: [testComplaint(technicianSuspended: true)],
            total: 1,
          ),
        ),
      );
      await pump(tester);

      await openComplaints(tester);

      expect(find.text(l10n.adminComplaintSuspend), findsNothing);
      expect(find.text(l10n.adminComplaintTechnicianSuspended), findsOneWidget);
    });

    testWidgets('says so when the complaint is gone and loads the list again', (
      tester,
    ) async {
      stubRequests(const Ok(PagedResult(items: [], total: 0)));
      stubComplaints(Ok(PagedResult(items: [testComplaint()], total: 1)));
      when(
        () => h.requests.resolveComplaint(any(), any()),
      ).thenAnswer((_) async => const Err(AdminNotFoundFailure()));
      await pump(tester);
      await openComplaints(tester);

      await tester.tap(resolveButton);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'تمام كده');
      await tester.pump();
      await tester.tap(inDialog(l10n.adminComplaintResolveConfirm));
      await tester.pumpAndSettle();

      expect(find.text(l10n.adminErrorNotFound), findsOneWidget);
      verify(
        () => h.requests.fetchComplaints(
          ComplaintFilter.open,
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).called(2);
    });
  });
}
