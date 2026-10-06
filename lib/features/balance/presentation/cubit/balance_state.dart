part of 'balance_cubit.dart';

enum BalanceStatus { loading, ready, failed }

final class BalanceState extends Equatable {
  const BalanceState({
    this.status = BalanceStatus.loading,
    this.topups = const [],
    this.ledger = const [],
    this.failure,
  });

  final BalanceStatus status;

  /// The transfers, newest first.
  final List<Topup> topups;

  /// The movements of the balance, newest first.
  final List<LedgerEntry> ledger;

  /// Why the last load failed; the lists keep what was shown before.
  final Failure? failure;

  @override
  List<Object?> get props => [status, topups, ledger, failure];
}
