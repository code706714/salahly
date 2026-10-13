import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/presentation/cubit/secure_payment_cubit.dart';
import 'package:salahly/features/escrow/presentation/pages/secure_payment_page.dart';

import '../../../../helpers/balance_fixtures.dart';
import '../../../../helpers/follow_up_harness.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pushed_view.dart';
import '../../../../pump_app.dart';

class MockSecurePaymentCubit extends MockCubit<SecurePaymentState>
    implements SecurePaymentCubit {}

void main() {
  late MockSecurePaymentCubit cubit;
  late MockSessionCubit session;
  late MockPhotoPicker photoPicker;

  setUpAll(() async {
    await loadAppFonts();
    FollowUpHarness.registerFallbacks();
    registerFallbackValue(PhotoSource.camera);
    registerFallbackValue(PhotoPurpose.transfer);
  });

  setUp(() {
    cubit = MockSecurePaymentCubit();
    session = MockSessionCubit();
    photoPicker = MockPhotoPicker();
    when(() => session.state).thenReturn(consumerSession());
    when(() => cubit.isClosed).thenReturn(false);
    when(() => cubit.submit()).thenAnswer((_) async {});
  });

  const editing = SecurePaymentState(
    status: SecurePaymentStatus.editing,
    amountPiastres: 35000,
    accounts: paymentAccounts,
    method: TopupMethod.instapay,
  );

  Future<void> pump(
    WidgetTester tester,
    SecurePaymentState state, {
    Honorific honorific = Honorific.ms,
    bool pushed = false,
  }) async {
    when(() => session.state).thenReturn(consumerSession(honorific: honorific));
    when(() => cubit.state).thenReturn(state);
    await tester.pumpApp(
      pushed
          ? const PushedView(SecurePaymentView())
          : const SecurePaymentView(),
      repositories: [RepositoryProvider<PhotoPicker>.value(value: photoPicker)],
      blocs: [
        BlocProvider<SessionCubit>.value(value: session),
        BlocProvider<SecurePaymentCubit>.value(value: cubit),
      ],
      surfaceSize: const Size(360, 1400),
    );
    if (pushed) {
      await tester.openPushedView();
    } else {
      await tester.pump();
    }
  }

  Finder submit() =>
      find.widgetWithText(FilledButton, l10n.buyUsesSubmit('ms'));

  testWidgets('shows what to transfer and where, in three steps', (
    tester,
  ) async {
    await pump(tester, editing);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.escrowSecureTitle('ms')), findsOneWidget);
    expect(find.text(l10n.escrowSecureIntro('ms', '350')), findsOneWidget);
    expect(find.text(l10n.buyUsesStepTransfer('ms', '350')), findsOneWidget);
    expect(find.text(l10n.buyUsesStepSender('ms')), findsOneWidget);
    expect(find.text(l10n.buyUsesStepScreenshot('ms')), findsOneWidget);
    for (final number in ['1', '2', '3']) {
      expect(find.text(number), findsOneWidget);
    }
    expect(find.text('salahly@instapay'), findsOneWidget);
  });

  testWidgets('speaks to a man as a man', (tester) async {
    await pump(tester, editing, honorific: Honorific.mr);

    expect(find.text(l10n.escrowSecureTitle('mr')), findsOneWidget);
    expect(find.text(l10n.escrowSecureIntro('mr', '350')), findsOneWidget);
  });

  testWidgets('switches to the wallet', (tester) async {
    await pump(tester, editing);

    await tester.tap(find.text(l10n.buyUsesMethodWallet));

    verify(() => cubit.pickMethod(TopupMethod.wallet)).called(1);
  });

  testWidgets('passes what is typed as the sender', (tester) async {
    await pump(tester, editing);

    await tester.enterText(find.byType(TextField), '٠١١١٤٥٦٧٧٢٠');

    verify(() => cubit.setSender('٠١١١٤٥٦٧٧٢٠')).called(1);
  });

  testWidgets('can not be sent before the form is complete', (tester) async {
    await pump(tester, editing);

    expect(tester.widget<FilledButton>(submit()).onPressed, isNull);
  });

  testWidgets('sends once the form is complete', (tester) async {
    await pump(
      tester,
      editing.copyWith(sender: '01114567720', screenshot: () => '/tmp/p.jpg'),
    );

    await tester.tap(submit());

    verify(() => cubit.submit()).called(1);
  });

  testWidgets('shows the payment being sent', (tester) async {
    await pump(
      tester,
      editing
          .copyWith(sender: '01114567720', screenshot: () => '/tmp/p.jpg')
          .copyWith(status: SecurePaymentStatus.submitting),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('says it is unavailable when the payment can not be made', (
    tester,
  ) async {
    await pump(
      tester,
      const SecurePaymentState(status: SecurePaymentStatus.failed),
    );

    expect(find.text(l10n.escrowSecureUnavailable('ms')), findsOneWidget);
    expect(submit(), findsNothing);
  });

  testWidgets('shows a loading mark while it loads', (tester) async {
    await pump(tester, const SecurePaymentState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  for (final (failure, text) in <(Failure, String)>[
    (const EscrowUnavailableFailure(), l10n.escrowFailureUnavailable),
    (const AlreadySecuredFailure(), l10n.escrowFailureAlreadySecured),
    (const InvalidSenderFailure(), l10n.buyUsesInvalidSender('ms')),
    (const InvalidScreenshotFailure(), l10n.buyUsesInvalidScreenshot('ms')),
  ]) {
    testWidgets('says why it was refused: $failure', (tester) async {
      whenListen(
        cubit,
        Stream.value(editing.copyWith(failure: () => failure)),
        initialState: editing,
      );
      await pump(tester, editing);
      await tester.pump();

      expect(find.text(text), findsOneWidget);
    });
  }

  testWidgets('closes with a thank-you once the transfer is sent', (
    tester,
  ) async {
    final sent = editing.copyWith(status: SecurePaymentStatus.submitted);
    whenListen(cubit, Stream.value(sent), initialState: editing);
    await pump(tester, editing, pushed: true);
    await tester.pumpAndSettle();

    expect(find.text(PushedView.launcher), findsOneWidget);
    expect(find.text(l10n.escrowSecureSent), findsOneWidget);
  });
}
