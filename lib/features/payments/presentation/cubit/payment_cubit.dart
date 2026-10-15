import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';

part 'payment_state.dart';

/// Follows one online payment: opens the provider's page and asks the server
/// until it says how the order ended. Only the server's answer ends it.
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit({
    required this._payments,
    required this._apps,
    required this._checkout,
    this.pollEvery = const Duration(seconds: 3),
  }) : super(const PaymentState());

  final PaymentRepository _payments;
  final ExternalApps _apps;
  final PaymentCheckout _checkout;
  final Duration pollEvery;

  Timer? _timer;
  bool _asking = false;

  /// Opens the payment page and starts asking.
  Future<void> start() async {
    _timer = Timer.periodic(pollEvery, (_) => unawaited(refresh()));
    await open();
  }

  /// Opens the payment page (again).
  Future<void> open() async {
    final opened = await _apps.openLink(_checkout.url);
    if (isClosed) return;
    emit(state.copyWith(pageOpened: opened));
  }

  /// Asks the server how the order stands. A failed ask keeps waiting, and so
  /// does a declined try: the checkout lets the person try another card, and
  /// a later success must still be seen (or they would pay twice).
  Future<void> refresh() async {
    if (_asking || state.progress == PaymentProgress.paid) return;
    _asking = true;
    final result = await _payments.fetchOrder(_checkout.orderId);
    _asking = false;
    if (isClosed) return;
    if (result case Ok(:final value)) {
      final progress = switch (value.status) {
        PaymentStatus.created ||
        PaymentStatus.pending => PaymentProgress.waiting,
        PaymentStatus.succeeded => PaymentProgress.paid,
        _ => PaymentProgress.notPaid,
      };
      emit(state.copyWith(progress: progress, status: value.status));
      final settled =
          progress == PaymentProgress.paid ||
          (progress == PaymentProgress.notPaid &&
              value.status != PaymentStatus.failed);
      if (settled) _timer?.cancel();
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
