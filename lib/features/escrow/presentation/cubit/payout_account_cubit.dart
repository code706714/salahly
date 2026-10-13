import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/sender_account.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';

part 'payout_account_state.dart';

/// Where Salahly pays the technician for guaranteed jobs.
class PayoutAccountCubit extends Cubit<PayoutAccountState> {
  PayoutAccountCubit(this._escrow) : super(const PayoutAccountState());

  final EscrowRepository _escrow;

  /// Fetches the saved account, if any.
  Future<void> load() async {
    emit(const PayoutAccountState());
    final result = await _escrow.fetchPayoutAccount();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          PayoutAccountState(
            status: PayoutAccountStatus.editing,
            method: value?.method ?? TopupMethod.wallet,
            account: value?.account ?? '',
            holder: value?.holderName ?? '',
          ),
        );
      case Err(:final failure):
        emit(
          PayoutAccountState(
            status: PayoutAccountStatus.failed,
            failure: failure,
          ),
        );
    }
  }

  void pickMethod(TopupMethod method) =>
      emit(state.copyWith(method: method, failure: () => null));

  void setAccount(String account) =>
      emit(state.copyWith(account: account, failure: () => null));

  void setHolder(String holder) =>
      emit(state.copyWith(holder: holder, failure: () => null));

  Future<void> save() async {
    final account = state.validAccount;
    final holder = state.validHolder;
    if (!state.canSave || account == null || holder == null) return;
    emit(
      state.copyWith(status: PayoutAccountStatus.saving, failure: () => null),
    );
    final result = await _escrow.savePayoutAccount(
      PayoutAccount(
        method: state.method,
        account: account,
        holderName: holder,
      ),
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(status: PayoutAccountStatus.saved));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: PayoutAccountStatus.editing,
            failure: () => failure,
          ),
        );
    }
  }
}
