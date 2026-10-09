import 'package:equatable/equatable.dart';

/// What moved a balance.
enum LedgerReason {
  requestSent,
  requestRefunded,
  jobFinished,
  topup,
  adminAdjustment,
  freeGrant,
  openingBalance,
}

/// One movement of the balance: [delta] uses taken (negative) or added.
final class LedgerEntry extends Equatable {
  const LedgerEntry({
    required this.id,
    required this.delta,
    required this.reason,
    required this.createdAt,
  });

  final int id;
  final int delta;
  final LedgerReason reason;
  final DateTime createdAt;

  @override
  List<Object?> get props => [id, delta, reason, createdAt];
}
