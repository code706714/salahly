import 'package:equatable/equatable.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';

/// Where a guaranteed payment stands.
enum EscrowStatus {
  /// A transfer made the old way (by screenshot) that Salahly is still
  /// checking. Online payments are only recorded once confirmed.
  pending,

  /// The payment was confirmed by the provider and the money is kept by
  /// Salahly until the work is confirmed.
  held,

  /// The work is confirmed; the technician is owed the money.
  released,

  /// Salahly paid the technician.
  paidOut,

  /// The consumer objected; Salahly decides.
  disputed,

  /// The money goes back to the consumer.
  refundDue,
  refunded,

  /// The transfer was not found.
  rejected,
}

/// The consumer's guaranteed payment for a request.
final class Escrow extends Equatable {
  const Escrow({
    required this.status,
    required this.createdAt,
    this.method,
    this.rejectReason,
    this.autoReleaseAt,
  });

  final EscrowStatus status;

  /// How an old-style transfer was made; null for an online payment.
  final TopupMethod? method;
  final String? rejectReason;
  final DateTime createdAt;

  /// When held money goes to the technician if the consumer says nothing.
  final DateTime? autoReleaseAt;

  @override
  List<Object?> get props => [
    status,
    method,
    rejectReason,
    createdAt,
    autoReleaseAt,
  ];
}

/// What the consumer sees of a request's guarantee: the amount, how her
/// online payment stands and what she can do now.
final class EscrowInfo extends Equatable {
  const EscrowInfo({
    required this.amountPiastres,
    required this.canSecure,
    required this.canConfirm,
    required this.canDispute,
    this.paymentStatus,
    this.escrow,
  });

  final int amountPiastres;
  final bool canSecure;
  final bool canConfirm;
  final bool canDispute;

  /// The latest online payment for the request, if one was started.
  final PaymentStatus? paymentStatus;
  final Escrow? escrow;

  /// Whether a payment was started and the provider has not decided yet.
  bool get paymentInProgress => paymentStatus?.isOpen ?? false;

  /// Whether the card has anything to say: a payment, or the offer to make
  /// one.
  bool get isRelevant => escrow != null || canSecure;

  @override
  List<Object?> get props => [
    amountPiastres,
    canSecure,
    canConfirm,
    canDispute,
    paymentStatus,
    escrow,
  ];
}

/// The technician's view of the consumer's guaranteed payment.
final class TechnicianEscrow extends Equatable {
  const TechnicianEscrow({required this.status, required this.amountPiastres});

  final EscrowStatus status;
  final int amountPiastres;

  @override
  List<Object?> get props => [status, amountPiastres];
}

/// Where Salahly pays a technician.
final class PayoutAccount extends Equatable {
  const PayoutAccount({
    required this.method,
    required this.account,
    required this.holderName,
  });

  final TopupMethod method;
  final String account;
  final String holderName;

  @override
  List<Object?> get props => [method, account, holderName];
}
