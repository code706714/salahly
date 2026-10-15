import 'package:equatable/equatable.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';

/// A guaranteed payment as the team works through it: checking the
/// transfer, paying the technician, settling a dispute or returning the
/// money.
final class EscrowReview extends Equatable {
  const EscrowReview({
    required this.id,
    required this.requestCode,
    required this.status,
    required this.amountPiastres,
    required this.createdAt,
    this.method,
    this.senderAccount,
    this.screenshotPath,
    this.onlineMethod,
    this.consumerName,
    this.consumerPhone,
    this.technicianName,
    this.technicianPhone,
    this.payoutMethod,
    this.payoutAccount,
    this.payoutHolder,
    this.payoutReference,
    this.refundReference,
    this.rejectReason,
    this.disputeReason,
    this.resolutionNote,
  });

  final String id;

  /// The short code the request is known by.
  final String requestCode;
  final EscrowStatus status;
  final int amountPiastres;

  /// For a transfer made the old way: how the consumer paid Salahly, the
  /// number or address the money came from (also where a refund goes) and
  /// the screenshot in the `transfer-proofs` bucket. All null for a payment
  /// made online.
  final TopupMethod? method;
  final String? senderAccount;
  final String? screenshotPath;

  /// How an online payment was made ("card", "wallet"); null when the
  /// provider did not say, or for an old-style transfer.
  final String? onlineMethod;
  final DateTime createdAt;

  /// Whether the consumer paid online, through the payment provider.
  bool get isOnline => screenshotPath == null;

  /// Null when the person deleted their account.
  final String? consumerName;
  final String? consumerPhone;
  final String? technicianName;
  final String? technicianPhone;

  /// Where the technician is paid; null until he sets an account.
  final TopupMethod? payoutMethod;
  final String? payoutAccount;
  final String? payoutHolder;

  /// The reference of the transfer to the technician, once paid.
  final String? payoutReference;

  /// The reference of the transfer back to the consumer, once refunded.
  final String? refundReference;
  final String? rejectReason;
  final String? disputeReason;
  final String? resolutionNote;

  @override
  List<Object?> get props => [
    id,
    requestCode,
    status,
    amountPiastres,
    method,
    senderAccount,
    screenshotPath,
    onlineMethod,
    createdAt,
    consumerName,
    consumerPhone,
    technicianName,
    technicianPhone,
    payoutMethod,
    payoutAccount,
    payoutHolder,
    payoutReference,
    refundReference,
    rejectReason,
    disputeReason,
    resolutionNote,
  ];
}

/// What the guarantee list is narrowed to.
final class EscrowFilter extends Equatable {
  const EscrowFilter({this.status = EscrowStatus.pending});

  /// The status to show; null for every one.
  final EscrowStatus? status;

  @override
  List<Object?> get props => [status];
}
