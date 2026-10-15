import 'package:equatable/equatable.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';

/// Where a move of money in the wallet came from.
enum WalletEntryKind {
  /// A job's money, released after both sides confirmed the work.
  escrow,

  /// Money asked out of the wallet.
  withdrawal,

  /// A withdrawal that could not be made: the money came back.
  withdrawalRefund,
}

/// One move of money in or out of the wallet; negative amounts leave it.
final class WalletEntry extends Equatable {
  const WalletEntry({
    required this.id,
    required this.kind,
    required this.amountPiastres,
    required this.createdAt,
    this.requestCode,
  });

  final int id;
  final WalletEntryKind kind;
  final int amountPiastres;
  final DateTime createdAt;

  /// The job the money came from, for [WalletEntryKind.escrow].
  final String? requestCode;

  @override
  List<Object?> get props => [id, kind, amountPiastres, createdAt, requestCode];
}

enum WithdrawalStatus {
  /// Asked for; Salahly has not sent it yet.
  requested,

  /// Sent to the number given.
  paid,

  /// Not sent; the money is back in the wallet.
  rejected,
}

/// A request to take money out to a Vodafone Cash number or an InstaPay
/// address.
final class Withdrawal extends Equatable {
  const Withdrawal({
    required this.id,
    required this.amountPiastres,
    required this.method,
    required this.account,
    required this.status,
    required this.createdAt,
    this.reference,
    this.rejectReason,
  });

  final String id;
  final int amountPiastres;
  final TopupMethod method;
  final String account;
  final WithdrawalStatus status;
  final DateTime createdAt;

  /// The transfer's reference, once paid.
  final String? reference;
  final String? rejectReason;

  @override
  List<Object?> get props => [
    id,
    amountPiastres,
    method,
    account,
    status,
    createdAt,
    reference,
    rejectReason,
  ];
}

/// The number the technician last withdrew to, to fill the form with.
final class WithdrawalDestination extends Equatable {
  const WithdrawalDestination({
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

/// The technician's wallet: what he can withdraw and what moved.
final class Wallet extends Equatable {
  const Wallet({
    required this.balancePiastres,
    required this.minWithdrawalPiastres,
    required this.entries,
    required this.withdrawals,
    this.lastDestination,
  });

  final int balancePiastres;

  /// The smallest amount that can be withdrawn.
  final int minWithdrawalPiastres;

  /// The latest moves, newest first.
  final List<WalletEntry> entries;

  /// The latest withdrawals, newest first.
  final List<Withdrawal> withdrawals;
  final WithdrawalDestination? lastDestination;

  /// Whether the balance reaches the smallest withdrawal.
  bool get canWithdraw => balancePiastres >= minWithdrawalPiastres;

  @override
  List<Object?> get props => [
    balancePiastres,
    minWithdrawalPiastres,
    entries,
    withdrawals,
    lastDestination,
  ];
}
