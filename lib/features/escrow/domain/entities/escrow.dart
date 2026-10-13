import 'package:equatable/equatable.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';

/// Where a guaranteed payment stands.
enum EscrowStatus {
  /// The consumer says she transferred; Salahly checks it.
  pending,

  /// The money reached Salahly and is kept until the work is confirmed.
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
    required this.method,
    required this.createdAt,
    this.rejectReason,
    this.autoReleaseAt,
  });

  final EscrowStatus status;
  final TopupMethod method;
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

/// What the consumer sees of a request's guarantee: the amount, where to
/// transfer it and what she can do now.
final class EscrowInfo extends Equatable {
  const EscrowInfo({
    required this.amountPiastres,
    required this.canSecure,
    required this.canConfirm,
    required this.canDispute,
    required this.accounts,
    this.escrow,
  });

  final int amountPiastres;
  final bool canSecure;
  final bool canConfirm;
  final bool canDispute;
  final List<PaymentAccount> accounts;
  final Escrow? escrow;

  /// Whether the card has anything to say: a payment, or the offer to make
  /// one.
  bool get isRelevant => escrow != null || canSecure;

  @override
  List<Object?> get props => [
    amountPiastres,
    canSecure,
    canConfirm,
    canDispute,
    accounts,
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
