import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';
import 'package:salahly/features/escrow/presentation/pages/payout_account_page.dart';

import '../../../../helpers/mocks.dart';
import '../../../../helpers/pushed_view.dart';
import '../../../../pump_app.dart';

void main() {
  late MockEscrowRepository escrow;

  const saved = PayoutAccount(
    method: TopupMethod.wallet,
    account: '01114567720',
    holderName: 'محمود سعيد',
  );

  setUpAll(() async {
    await loadAppFonts();
    registerFallbackValue(saved);
  });

  setUp(() {
    escrow = MockEscrowRepository();
    when(
      () => escrow.fetchPayoutAccount(),
    ).thenAnswer((_) async => const Ok(saved));
    when(
      () => escrow.savePayoutAccount(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(
      const PushedView(PayoutAccountPage()),
      repositories: [RepositoryProvider<EscrowRepository>.value(value: escrow)],
    );
    await tester.openPushedView();
  }

  Finder save() => find.widgetWithText(FilledButton, l10n.payoutAccountSave);

  testWidgets('shows the saved account in the fields', (tester) async {
    await pump(tester);

    expect(find.text(l10n.payoutAccountTitle), findsWidgets);
    expect(find.text(l10n.payoutAccountIntro), findsOneWidget);
    expect(find.text('01114567720'), findsOneWidget);
    expect(find.text('محمود سعيد'), findsOneWidget);
    expect(tester.widget<FilledButton>(save()).onPressed, isNotNull);
  });

  testWidgets('starts empty and can not be saved before one is set', (
    tester,
  ) async {
    when(
      () => escrow.fetchPayoutAccount(),
    ).thenAnswer((_) async => const Ok(null));

    await pump(tester);

    expect(tester.widget<FilledButton>(save()).onPressed, isNull);
  });

  testWidgets('saves what was changed and goes back', (tester) async {
    await pump(tester);

    await tester.enterText(
      find.widgetWithText(TextField, '01114567720'),
      '01005551234',
    );
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();

    verify(
      () => escrow.savePayoutAccount(
        const PayoutAccount(
          method: TopupMethod.wallet,
          account: '01005551234',
          holderName: 'محمود سعيد',
        ),
      ),
    ).called(1);
    expect(find.text(PushedView.launcher), findsOneWidget);
    expect(find.text(l10n.payoutAccountSaved), findsOneWidget);
  });

  testWidgets('switches to an InstaPay address', (tester) async {
    await pump(tester);

    await tester.tap(find.text(l10n.buyUsesMethodInstapay));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, '01114567720'),
      'mahmoud@instapay',
    );
    await tester.pump();
    await tester.tap(save());
    await tester.pumpAndSettle();

    verify(
      () => escrow.savePayoutAccount(
        const PayoutAccount(
          method: TopupMethod.instapay,
          account: 'mahmoud@instapay',
          holderName: 'محمود سعيد',
        ),
      ),
    ).called(1);
  });

  for (final (failure, text) in <(Failure, String)>[
    (const InvalidHolderFailure(), l10n.payoutAccountInvalidHolder),
    (const InvalidPayoutAccountFailure(), l10n.payoutAccountInvalidAccount),
    (const NetworkFailure(), l10n.errorNetwork),
  ]) {
    testWidgets('says why a save was refused: $failure', (tester) async {
      when(
        () => escrow.savePayoutAccount(any()),
      ).thenAnswer((_) async => Err(failure));
      await pump(tester);

      await tester.tap(save());
      await tester.pumpAndSettle();

      expect(find.text(text), findsOneWidget);
    });
  }

  testWidgets('offers a retry when the account can not be read', (
    tester,
  ) async {
    when(
      () => escrow.fetchPayoutAccount(),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    await pump(tester);

    expect(find.text(l10n.payoutAccountUnavailable), findsOneWidget);
    when(
      () => escrow.fetchPayoutAccount(),
    ).thenAnswer((_) async => const Ok(saved));
    await tester.tap(find.text(l10n.retry));
    await tester.pumpAndSettle();

    expect(find.text('01114567720'), findsOneWidget);
  });
}
