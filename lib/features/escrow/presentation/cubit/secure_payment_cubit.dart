import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';

part 'secure_payment_state.dart';

/// Paying a request's price to Salahly online. The amount is the server's;
/// the money counts as held only once the server confirmed the payment.
class SecurePaymentCubit extends Cubit<SecurePaymentState> {
  SecurePaymentCubit({
    required this._escrow,
    required this._payments,
    required this._requestId,
  }) : super(const SecurePaymentState());

  final EscrowRepository _escrow;
  final PaymentRepository _payments;
  final String _requestId;

  /// Fetches the amount to pay.
  Future<void> load() async {
    emit(const SecurePaymentState());
    final result = await _escrow.fetchInfo(_requestId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final info?) when info.canSecure:
        emit(
          SecurePaymentState(
            status: SecurePaymentStatus.editing,
            amountPiastres: info.amountPiastres,
          ),
        );
      case Err(:final failure):
        emit(
          SecurePaymentState(
            status: SecurePaymentStatus.failed,
            failure: failure,
          ),
        );
      default:
        emit(const SecurePaymentState(status: SecurePaymentStatus.failed));
    }
  }

  /// Starts the payment on the server.
  Future<void> pay() async {
    if (!state.canPay) return;
    emit(
      state.copyWith(status: SecurePaymentStatus.starting, failure: () => null),
    );
    final result = await _payments.startEscrowPayment(_requestId);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: SecurePaymentStatus.paying,
            checkout: () => value,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: SecurePaymentStatus.editing,
            failure: () => failure,
          ),
        );
    }
  }

  /// The payment screen was closed: back to the amount.
  void paymentClosed() {
    if (state.status != SecurePaymentStatus.paying) return;
    emit(
      state.copyWith(status: SecurePaymentStatus.editing, checkout: () => null),
    );
  }
}
