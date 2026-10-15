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

  /// The money is in the technician's wallet.
  paidOut,

  /// Either side objected; Salahly decides.
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
    this.consumerConfirmed = false,
    this.technicianConfirmed = false,
    this.releaseAt,
  });

  final EscrowStatus status;

  /// How an old-style transfer was made; null for an online payment.
  final TopupMethod? method;
  final String? rejectReason;
  final DateTime createdAt;

  /// Each side has said the work is done and right.
  final bool consumerConfirmed;
  final bool technicianConfirmed;

  /// When held money reaches the technician's wallet unless someone
  /// objects; null while a confirmation is still missing.
  final DateTime? releaseAt;

  @override
  List<Object?> get props => [
    status,
    method,
    rejectReason,
    createdAt,
    consumerConfirmed,
    technicianConfirmed,
    releaseAt,
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

/// The technician's view of the consumer's guaranteed payment: where it
/// stands and what he can do now.
final class TechnicianEscrow extends Equatable {
  const TechnicianEscrow({
    required this.status,
    required this.amountPiastres,
    required this.canConfirm,
    required this.canDispute,
    required this.consumerConfirmed,
    required this.technicianConfirmed,
    this.releaseAt,
  });

  final EscrowStatus status;
  final int amountPiastres;
  final bool canConfirm;
  final bool canDispute;
  final bool consumerConfirmed;
  final bool technicianConfirmed;

  /// When the money reaches his wallet unless someone objects.
  final DateTime? releaseAt;

  @override
  List<Object?> get props => [
    status,
    amountPiastres,
    canConfirm,
    canDispute,
    consumerConfirmed,
    technicianConfirmed,
    releaseAt,
  ];
}
