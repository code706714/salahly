import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/account/presentation/pages/account_deleted_page.dart';
import 'package:salahly/features/account/presentation/pages/delete_account_page.dart';

import '../../../helpers/consumer_app.dart';
import '../../../helpers/technician_app.dart';
import '../../../pump_app.dart';

Future<void> _confirmAndDelete(WidgetTester tester) async {
  await tester.tap(find.byType(Checkbox));
  await tester.pump();
  await tester.tap(find.text('امسح الحساب نهائي'));
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
  });

  testConsumerApp('a consumer deletes her account from the account tab', (
    tester,
    app,
  ) async {
    when(app.account.deleteAccount).thenAnswer((_) async => const Ok(null));
    when(app.auth.signOut).thenAnswer((_) async {});
    await app.pump(tester, location: '/consumer/account');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump();
    await tester.tap(find.text('امسح حسابي'));
    await app.settle(tester);
    expect(find.byType(DeleteAccountPage), findsOneWidget);

    await _confirmAndDelete(tester);
    await app.settle(tester);

    verify(app.account.deleteAccount).called(1);
    verify(app.auth.signOut).called(1);
    expect(find.byType(AccountDeletedPage), findsOneWidget);
    expect(
      find.text(
        'شكراً إنك جرّبتي الأبلكيشن. لو حبيتي ترجعي، سجّلي برقمك من الأول.',
      ),
      findsOneWidget,
    );
  });

  testConsumerApp(
    'stays on the screen and says why when a transfer is waiting',
    (
      tester,
      app,
    ) async {
      when(
        app.account.deleteAccount,
      ).thenAnswer((_) async => const Err(PendingTransferFailure()));
      await app.pump(tester, location: '/consumer/account/delete');

      await _confirmAndDelete(tester);
      await app.settle(tester);

      expect(find.byType(DeleteAccountPage), findsOneWidget);
      expect(find.textContaining('عندك تحويل لسه بنراجعه'), findsOneWidget);
      verifyNever(app.auth.signOut);
    },
    app: () => ConsumerApp(honorific: Honorific.mr),
  );

  testTechnicianApp('a technician deletes his account from his account page', (
    tester,
    app,
  ) async {
    when(app.account.deleteAccount).thenAnswer((_) async => const Ok(null));
    when(app.auth.signOut).thenAnswer((_) async {});
    await app.pump(tester, location: '/technician/account');

    await tester.ensureVisible(find.text('امسح حسابي'));
    await tester.tap(find.text('امسح حسابي'));
    await app.settle(tester);
    await _confirmAndDelete(tester);
    await app.settle(tester);

    verify(app.account.deleteAccount).called(1);
    verify(app.auth.signOut).called(1);
    expect(find.text('حسابك اتمسح'), findsOneWidget);
  });
}
