import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';
import 'package:salahly/features/payments/presentation/pages/payment_page.dart';

import '../../../../helpers/follow_up_harness.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pushed_view.dart';
import '../../../../pump_app.dart';

void main() {
  late MockPaymentRepository payments;
  late MockExternalApps apps;
  late MockSessionCubit session;

  final checkout = PaymentCheckout(
    orderId: 'order-1',
    url: Uri.parse('https://pay.example/checkout'),
    amountPiastres: 8000,
  );

  setUpAll(() async {
    await loadAppFonts();
    registerFallbackValue(Uri());
  });

  setUp(() {
    payments = MockPaymentRepository();
    apps = MockExternalApps();
    session = MockSessionCubit();
    when(() => session.state).thenReturn(consumerSession());
    when(() => apps.openLink(any())).thenAnswer((_) async => true);
  });

  void answer(PaymentStatus status) =>
      when(() => payments.fetchOrder('order-1')).thenAnswer(
        (_) async => Ok(PaymentOrder(id: 'order-1', status: status)),
      );

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpApp(
      PaymentPage(checkout: checkout),
      repositories: [
        RepositoryProvider<PaymentRepository>.value(value: payments),
        RepositoryProvider<ExternalApps>.value(value: apps),
      ],
      blocs: [BlocProvider<SessionCubit>.value(value: session)],
      surfaceSize: const Size(360, 800),
    );
    await tester.pump();
  }

  /// Lets the poll run once.
  Future<void> poll(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 3));
    await tester.pump();
  }

  testWidgets('opens the provider page and waits, saying the amount', (
    tester,
  ) async {
    answer(PaymentStatus.created);

    await pump(tester);

    verify(() => apps.openLink(checkout.url)).called(1);
    expect(find.text(l10n.paymentTitle), findsOneWidget);
    expect(find.text(l10n.paymentWaitingTitle), findsOneWidget);
    expect(find.text(l10n.paymentOpenBody), findsOneWidget);
    expect(find.text(l10n.paymentAmount('80')), findsOneWidget);
  });

  testWidgets('says it is waiting for the person to approve a wallet', (
    tester,
  ) async {
    answer(PaymentStatus.pending);

    await pump(tester);
    await poll(tester);

    expect(find.text(l10n.paymentWaitingBody), findsOneWidget);
    expect(find.text(l10n.paymentPaidTitle), findsNothing);
  });

  testWidgets('opens the provider page again on request', (tester) async {
    answer(PaymentStatus.created);
    await pump(tester);

    await tester.tap(find.text(l10n.paymentOpenAgain('ms')));
    await tester.pump();

    verify(() => apps.openLink(checkout.url)).called(2);
  });

  testWidgets('says it is paid only after the server confirmed it', (
    tester,
  ) async {
    answer(PaymentStatus.succeeded);

    await pump(tester);
    expect(find.text(l10n.paymentPaidTitle), findsNothing);
    await poll(tester);

    expect(find.text(l10n.paymentPaidTitle), findsOneWidget);
    expect(find.text(l10n.paymentPaidBody), findsOneWidget);
    expect(find.text(l10n.paymentDone), findsOneWidget);
    expect(find.text(l10n.paymentLater), findsNothing);
  });

  for (final (status, body) in <(PaymentStatus, String)>[
    (PaymentStatus.failed, l10n.paymentFailedBody),
    (PaymentStatus.cancelled, l10n.paymentFailedBody),
    (PaymentStatus.expired, l10n.paymentExpiredBody),
    (PaymentStatus.refunded, l10n.paymentRefundedBody),
  ]) {
    testWidgets('says a $status payment did not go through', (tester) async {
      answer(status);

      await pump(tester);
      await poll(tester);

      expect(find.text(l10n.paymentFailedTitle), findsOneWidget);
      expect(find.text(body), findsOneWidget);
      expect(find.text(l10n.paymentBack), findsOneWidget);
    });
  }

  testWidgets('keeps waiting when the server can not be reached', (
    tester,
  ) async {
    when(
      () => payments.fetchOrder('order-1'),
    ).thenAnswer((_) async => const Err(NetworkFailure()));

    await pump(tester);
    await poll(tester);

    expect(find.text(l10n.paymentWaitingTitle), findsOneWidget);
    expect(find.text(l10n.paymentFailedTitle), findsNothing);
  });

  testWidgets('asks the server right away when the app comes back', (
    tester,
  ) async {
    answer(PaymentStatus.created);
    await pump(tester);
    clearInteractions(payments);
    answer(PaymentStatus.succeeded);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    verify(() => payments.fetchOrder('order-1')).called(1);
    expect(find.text(l10n.paymentPaidTitle), findsOneWidget);
  });

  group('leaving', () {
    Future<void> pushed(WidgetTester tester) async {
      await tester.pumpApp(
        PushedView(PaymentPage(checkout: checkout)),
        repositories: [
          RepositoryProvider<PaymentRepository>.value(value: payments),
          RepositoryProvider<ExternalApps>.value(value: apps),
        ],
        blocs: [BlocProvider<SessionCubit>.value(value: session)],
        surfaceSize: const Size(360, 800),
      );
      await tester.tap(find.text(PushedView.launcher));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('later goes back and the payment still completes', (
      tester,
    ) async {
      answer(PaymentStatus.pending);
      await pushed(tester);

      await tester.tap(find.text(l10n.paymentLater));
      await tester.pumpAndSettle();

      expect(find.text(PushedView.launcher), findsOneWidget);
    });

    testWidgets('done goes back once paid', (tester) async {
      answer(PaymentStatus.succeeded);
      await pushed(tester);
      await poll(tester);

      await tester.tap(find.text(l10n.paymentDone));
      await tester.pumpAndSettle();

      expect(find.text(PushedView.launcher), findsOneWidget);
    });
  });
}
