part of 'secure_payment_cubit.dart';

enum SecurePaymentStatus { loading, failed, editing, starting, paying }

final class SecurePaymentState extends Equatable {
  const SecurePaymentState({
    this.status = SecurePaymentStatus.loading,
    this.amountPiastres = 0,
    this.checkout,
    this.failure,
  });

  final SecurePaymentStatus status;

  /// What will be charged: the agreed price, decided by the server.
  final int amountPiastres;

  /// The payment page to pay on, while [status] is `paying`.
  final PaymentCheckout? checkout;

  /// Why loading or the last start failed.
  final Failure? failure;

  bool get canPay => status == SecurePaymentStatus.editing;

  SecurePaymentState copyWith({
    SecurePaymentStatus? status,
    PaymentCheckout? Function()? checkout,
    Failure? Function()? failure,
  }) {
    return SecurePaymentState(
      status: status ?? this.status,
      amountPiastres: amountPiastres,
      checkout: checkout != null ? checkout() : this.checkout,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, amountPiastres, checkout, failure];
}
