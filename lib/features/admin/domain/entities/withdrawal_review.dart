import 'package:equatable/equatable.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

/// A technician's request to take money out of his wallet, as the team
/// works through it: send the money to the number he typed, then record the
/// transfer.
final class WithdrawalReview extends Equatable {
  const WithdrawalReview({
    required this.id,
    required this.status,
    required this.amountPiastres,
    required this.method,
    required this.account,
    required this.holderName,
    required this.createdAt,
    this.technicianName,
    this.technicianPhone,
    this.reference,
    this.rejectReason,
    this.processedAt,
  });

  final String id;
  final WithdrawalStatus status;
  final int amountPiastres;

  /// Where to send it: a Vodafone Cash number or an InstaPay address, and
  /// the name on that account.
  final TopupMethod method;
  final String account;
  final String holderName;
  final DateTime createdAt;

  /// Null when the person deleted their account.
  final String? technicianName;
  final String? technicianPhone;

  /// The reference of the transfer, once paid.
  final String? reference;
  final String? rejectReason;
  final DateTime? processedAt;

  @override
  List<Object?> get props => [
    id,
    status,
    amountPiastres,
    method,
    account,
    holderName,
    createdAt,
    technicianName,
    technicianPhone,
    reference,
    rejectReason,
    processedAt,
  ];
}

/// What the withdrawal list is narrowed to.
final class WithdrawalFilter extends Equatable {
  const WithdrawalFilter({this.status = WithdrawalStatus.requested});

  /// The status to show; null for every one.
  final WithdrawalStatus? status;

  @override
  List<Object?> get props => [status];
}
