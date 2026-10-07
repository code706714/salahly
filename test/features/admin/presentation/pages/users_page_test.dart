import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/presentation/pages/users_page.dart';
import 'package:salahly/features/admin/presentation/router/admin_routes.dart';

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

  setUp(() => h = AdminHarness());

  void stubUsers(Result<PagedResult<AdminUser>> result) => when(
    () => h.users.fetchUsers(
      any(),
      limit: any(named: 'limit'),
      offset: any(named: 'offset'),
    ),
  ).thenAnswer((_) async => result);

  void stubUsersWith(List<AdminUser> users) =>
      stubUsers(Ok(PagedResult(items: users, total: users.length)));

  Future<void> pump(WidgetTester tester, {bool settle = true}) => h.pump(
    tester,
    const UsersPage(),
    path: AdminRoutes.users,
    size: const Size(1440, 1400),
    settle: settle,
  );

  Finder inDialog(String text) =>
      find.descendant(of: find.byType(AlertDialog), matching: find.text(text));

  testWidgets('shows a spinner while the list loads', (tester) async {
    final pending = Completer<Result<PagedResult<AdminUser>>>();
    when(
      () => h.users.fetchUsers(
        any(),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
      ),
    ).thenAnswer((_) => pending.future);

    await pump(tester, settle: false);
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says so when nobody matches', (tester) async {
    stubUsersWith(const []);

    await pump(tester);

    expect(find.text(l10n.adminUsersEmpty), findsOneWidget);
  });

  testWidgets('says why the list did not load and tries again', (tester) async {
    stubUsers(const Err(NetworkFailure()));
    await pump(tester);

    stubUsersWith([testAdminTechnician()]);
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text('سامي حسن'), findsOneWidget);
  });

  testWidgets('lists technicians and offers suspension to the active', (
    tester,
  ) async {
    stubUsersWith([
      testAdminTechnician(),
      testAdminTechnician(
        id: 'tech-2',
        name: 'مني كريم',
        status: AccountStatus.suspended,
        suspensionReason: '<i>شكاوي</i> متكررة',
      ),
    ]);

    await pump(tester);

    expect(find.text('سامي حسن'), findsOneWidget);
    expect(find.text(l10n.adminUsersSuspend), findsOneWidget);
    expect(find.text(l10n.adminUsersRestore), findsOneWidget);
    // The reason is shown as it was written, not as markup.
    expect(
      find.text(l10n.adminUsersReasonLine('<i>شكاوي</i> متكررة')),
      findsOneWidget,
    );
  });

  testWidgets('switches to the customers', (tester) async {
    stubUsersWith([testAdminTechnician()]);
    await pump(tester);

    stubUsersWith([testAdminConsumer()]);
    await tester.tap(find.text(l10n.adminUsersTabConsumers));
    await tester.pumpAndSettle();

    expect(find.text('نورهان محمد'), findsOneWidget);
    verify(
      () => h.users.fetchUsers(
        const UserFilter(role: UserRole.consumer),
        limit: any(named: 'limit'),
        offset: 0,
      ),
    ).called(1);
  });

  testWidgets('suspends only with a reason', (tester) async {
    stubUsersWith([testAdminTechnician()]);
    when(
      () => h.users.suspend(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    await pump(tester);

    await tester.tap(find.text(l10n.adminUsersSuspend));
    await tester.pumpAndSettle();
    TextButton confirm() => tester.widget<TextButton>(
      find.ancestor(
        of: inDialog(l10n.adminSuspendConfirm),
        matching: find.byType(TextButton),
      ),
    );
    expect(confirm().onPressed, isNull);

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'شكاوي متكررة',
    );
    await tester.pump();
    await tester.tap(inDialog(l10n.adminSuspendConfirm));
    await tester.pumpAndSettle();

    verify(() => h.users.suspend('tech-1', 'شكاوي متكررة')).called(1);
    expect(find.text(l10n.adminSuspended), findsOneWidget);
  });

  testWidgets('says admins can not be suspended', (tester) async {
    stubUsersWith([testAdminTechnician()]);
    when(
      () => h.users.suspend(any(), any()),
    ).thenAnswer((_) async => const Err(CannotSuspendAdminFailure()));
    await pump(tester);

    await tester.tap(find.text(l10n.adminUsersSuspend));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'سبب كافي',
    );
    await tester.pump();
    await tester.tap(inDialog(l10n.adminSuspendConfirm));
    await tester.pumpAndSettle();

    expect(find.text(l10n.adminErrorCannotSuspendAdmin), findsOneWidget);
  });

  testWidgets('restores after the admin confirms', (tester) async {
    stubUsersWith([
      testAdminTechnician(status: AccountStatus.suspended),
    ]);
    when(
      () => h.users.restore(any()),
    ).thenAnswer((_) async => const Ok(null));
    await pump(tester);

    await tester.tap(find.text(l10n.adminUsersRestore));
    await tester.pumpAndSettle();
    verifyNever(() => h.users.restore(any()));

    await tester.tap(inDialog(l10n.adminUsersRestoreConfirm));
    await tester.pumpAndSettle();

    verify(() => h.users.restore('tech-1')).called(1);
    expect(find.text(l10n.adminUsersRestored), findsOneWidget);
  });

  testWidgets('does not restore when the admin cancels', (tester) async {
    stubUsersWith([
      testAdminTechnician(status: AccountStatus.suspended),
    ]);
    await pump(tester);

    await tester.tap(find.text(l10n.adminUsersRestore));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.adminCancel));
    await tester.pumpAndSettle();

    verifyNever(() => h.users.restore(any()));
  });
}
