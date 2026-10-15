part of 'payment_cubit.dart';

/// What the payment screen says.
enum PaymentProgress {
  /// Waiting for the provider to confirm. The person may still be paying.
  waiting,

  /// The server confirmed the money.
  paid,

  /// It did not go through (declined, cancelled, expired or returned).
  notPaid,
}

final class PaymentState extends Equatable {
  const PaymentState({
    this.progress = PaymentProgress.waiting,
    this.status = PaymentStatus.created,
    this.pageOpened = false,
  });

  final PaymentProgress progress;

  /// The order's status as last read from the server.
  final PaymentStatus status;

  /// Whether the payment page could be opened on this phone.
  final bool pageOpened;

  PaymentState copyWith({
    PaymentProgress? progress,
    PaymentStatus? status,
    bool? pageOpened,
  }) => PaymentState(
    progress: progress ?? this.progress,
    status: status ?? this.status,
    pageOpened: pageOpened ?? this.pageOpened,
  );

  @override
  List<Object?> get props => [progress, status, pageOpened];
}
