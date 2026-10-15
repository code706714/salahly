import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/presentation/cubit/secure_payment_cubit.dart';
import 'package:salahly/features/escrow/presentation/pages/secure_payment_page.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/failures/payment_failures.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';

import '../../../../helpers/follow_up_harness.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pushed_view.dart';
import '../../../../pump_app.dart';

class MockSecurePaymentCubit extends MockCubit<SecurePaymentState>
    implements SecurePaymentCubit {}

void main() {
  late MockSecurePaymentCubit cubit;
  late MockSessionCubit session;
  late MockPaymentRepository payments;
  late MockExternalApps apps;

  final checkout = PaymentCheckout(
    orderId: 'order-1',
    url: Uri.parse('https://pay.example/checkout'),
    amountPiastres: 35000,
  );

  setUpAll(() async {
    await loadAppFonts();
    FollowUpHarness.registerFallbacks();
    registerFallbackValue(Uri());
  });

  setUp(() {
    cubit = MockSecurePaymentCubit();
    session = MockSessionCubit();
    payments = MockPaymentRepository();
    apps = MockExternalApps();
    when(() => session.state).thenReturn(consumerSession());
    when(() => cubit.isClosed).thenReturn(false);
    when(() => cubit.pay()).thenAnswer((_) async {});
    when(cubit.paymentClosed).thenReturn(null);
    when(() => apps.openLink(any())).thenAnswer((_) async => true);
  });

  const editing = SecurePaymentState(
    status: SecurePaymentStatus.editing,
    amountPiastres: 35000,
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
      repositories: [
        RepositoryProvider<PaymentRepository>.value(value: payments),
        RepositoryProvider<ExternalApps>.value(value: apps),
      ],
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

  Finder pay() =>
      find.widgetWithText(FilledButton, l10n.buyUsesPay('ms', '350'));

  testWidgets('shows what the guarantee is and what will be charged', (
    tester,
  ) async {
    await pump(tester, editing);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.escrowSecureTitle('ms')), findsOneWidget);
    expect(find.text(l10n.escrowSecureIntro('ms', '350')), findsOneWidget);
    expect(pay(), findsOneWidget);
  });

  testWidgets('speaks to a man as a man', (tester) async {
    await pump(tester, editing, honorific: Honorific.mr);

    expect(find.text(l10n.escrowSecureTitle('mr')), findsOneWidget);
    expect(find.text(l10n.escrowSecureIntro('mr', '350')), findsOneWidget);
  });

  testWidgets('starts the payment from the button', (tester) async {
    await pump(tester, editing);

    await tester.tap(pay());

    verify(() => cubit.pay()).called(1);
  });

  testWidgets('shows the payment being started and cannot pay twice', (
    tester,
  ) async {
    await pump(
      tester,
      editing.copyWith(status: SecurePaymentStatus.starting),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    verifyNever(() => cubit.pay());
  });

  testWidgets('says it is unavailable when the payment can not be made', (
    tester,
  ) async {
    await pump(
      tester,
      const SecurePaymentState(status: SecurePaymentStatus.failed),
    );

    expect(find.text(l10n.escrowSecureUnavailable('ms')), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('shows a loading mark while it loads', (tester) async {
    await pump(tester, const SecurePaymentState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  for (final (failure, text) in <(Failure, String)>[
    (const EscrowUnavailableFailure(), l10n.escrowFailureUnavailable),
    (const AlreadySecuredFailure(), l10n.escrowFailureAlreadySecured),
    (const PaymentsUnavailableFailure(), l10n.paymentsUnavailable('ms')),
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

  testWidgets('closes with a thank-you once the server confirmed it', (
    tester,
  ) async {
    when(() => payments.fetchOrder('order-1')).thenAnswer(
      (_) async => const Ok(
        PaymentOrder(id: 'order-1', status: PaymentStatus.succeeded),
      ),
    );
    final paying = editing.copyWith(
      status: SecurePaymentStatus.paying,
      checkout: () => checkout,
    );
    whenListen(cubit, Stream.value(paying), initialState: editing);
    await pump(tester, editing, pushed: true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(l10n.paymentDone));
    await tester.pumpAndSettle();

    expect(find.text(PushedView.launcher), findsOneWidget);
    expect(find.text(l10n.escrowSecurePaid), findsOneWidget);
    verify(() => cubit.paymentClosed()).called(1);
  });

  testWidgets('stays when the payment screen is left unpaid', (tester) async {
    when(() => payments.fetchOrder('order-1')).thenAnswer(
      (_) async =>
          const Ok(PaymentOrder(id: 'order-1', status: PaymentStatus.pending)),
    );
    final paying = editing.copyWith(
      status: SecurePaymentStatus.paying,
      checkout: () => checkout,
    );
    whenListen(cubit, Stream.value(paying), initialState: editing);
    await pump(tester, editing, pushed: true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text(l10n.paymentLater));
    await tester.pumpAndSettle();

    expect(find.byType(SecurePaymentView), findsOneWidget);
    expect(find.text(l10n.escrowSecurePaid), findsNothing);
    verify(() => cubit.paymentClosed()).called(1);
  });
}
