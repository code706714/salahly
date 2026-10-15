import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/features/balance/domain/entities/sender_account.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/repositories/wallet_repository.dart';

part 'withdraw_state.dart';

/// Asking for money out of the wallet: how much, and to which number.
class WithdrawCubit extends Cubit<WithdrawState> {
  WithdrawCubit(this._wallets) : super(const WithdrawState());

  final WalletRepository _wallets;

  /// Fetches the balance and the number last withdrawn to, to fill the form.
  Future<void> load() async {
    emit(const WithdrawState());
    final result = await _wallets.fetch();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final last = value.lastDestination;
        emit(
          WithdrawState(
            status: WithdrawStatus.editing,
            balancePiastres: value.balancePiastres,
            minPiastres: value.minWithdrawalPiastres,
            method: last?.method ?? TopupMethod.wallet,
            account: last?.account ?? '',
            holder: last?.holderName ?? '',
          ),
        );
      case Err(:final failure):
        emit(WithdrawState(status: WithdrawStatus.failed, failure: failure));
    }
  }

  void setAmount(String amount) =>
      emit(state.copyWith(amount: amount, failure: () => null));

  void pickMethod(TopupMethod method) =>
      emit(state.copyWith(method: method, failure: () => null));

  void setAccount(String account) =>
      emit(state.copyWith(account: account, failure: () => null));

  void setHolder(String holder) =>
      emit(state.copyWith(holder: holder, failure: () => null));

  Future<void> send() async {
    final amount = state.validAmount;
    final account = state.validAccount;
    final holder = state.validHolder;
    if (!state.canSend || amount == null || account == null || holder == null) {
      return;
    }
    emit(state.copyWith(status: WithdrawStatus.sending, failure: () => null));
    final result = await _wallets.requestWithdrawal(
      amountPiastres: amount,
      method: state.method,
      account: account,
      holderName: holder,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(status: WithdrawStatus.sent));
      case Err(:final failure):
        emit(
          state.copyWith(
            status: WithdrawStatus.editing,
            failure: () => failure,
          ),
        );
    }
  }
}
