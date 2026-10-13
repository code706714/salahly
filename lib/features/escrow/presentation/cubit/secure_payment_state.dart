part of 'secure_payment_cubit.dart';

enum SecurePaymentStatus { loading, failed, editing, submitting, submitted }

final class SecurePaymentState extends Equatable {
  const SecurePaymentState({
    this.status = SecurePaymentStatus.loading,
    this.amountPiastres = 0,
    this.accounts = const [],
    this.method,
    this.sender = '',
    this.screenshot,
    this.failure,
  });

  final SecurePaymentStatus status;

  /// What to transfer.
  final int amountPiastres;
  final List<PaymentAccount> accounts;
  final TopupMethod? method;

  /// The account the money comes from, as typed.
  final String sender;

  /// The local path of the transfer's screenshot.
  final String? screenshot;

  /// Why loading or the last send failed.
  final Failure? failure;

  /// The account to transfer to by the picked method.
  PaymentAccount? get account =>
      accounts.where((account) => account.method == method).firstOrNull;

  /// The sender as the server takes it, or null while it is not valid.
  String? get validSender {
    final method = this.method;
    return method == null ? null : normalizedSender(method, sender);
  }

  bool get canSubmit =>
      status == SecurePaymentStatus.editing &&
      account != null &&
      validSender != null &&
      screenshot != null;

  SecurePaymentState copyWith({
    SecurePaymentStatus? status,
    TopupMethod? method,
    String? sender,
    String? Function()? screenshot,
    Failure? Function()? failure,
  }) {
    return SecurePaymentState(
      status: status ?? this.status,
      amountPiastres: amountPiastres,
      accounts: accounts,
      method: method ?? this.method,
      sender: sender ?? this.sender,
      screenshot: screenshot != null ? screenshot() : this.screenshot,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    amountPiastres,
    accounts,
    method,
    sender,
    screenshot,
    failure,
  ];
}
