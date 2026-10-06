import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/async/single_flight.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/domain/repositories/balance_repository.dart';

part 'balance_state.dart';

/// The person's transfers and the movements of their balance.
class BalanceCubit extends Cubit<BalanceState> {
  BalanceCubit({required this._balance, required this._role})
    : super(const BalanceState());

  final BalanceRepository _balance;
  final UserRole _role;
  late final _fetch = SingleFlight(_fetchHistory);

  /// Fetches both lists again. A failed refresh keeps what is shown.
  Future<void> load() => _fetch();

  Future<void> _fetchHistory() async {
    final results = await (
      _balance.fetchTopups(_role),
      _balance.fetchLedger(_role),
    ).wait;
    if (isClosed) return;
    switch (results) {
      case (Ok(value: final topups), Ok(value: final ledger)):
        emit(
          BalanceState(
            status: BalanceStatus.ready,
            topups: topups,
            ledger: ledger,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(
          BalanceState(
            status: state.status == BalanceStatus.ready
                ? BalanceStatus.ready
                : BalanceStatus.failed,
            topups: state.topups,
            ledger: state.ledger,
            failure: failure,
          ),
        );
    }
  }
}
