import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';
import 'package:salahly/features/wallet/domain/repositories/wallet_repository.dart';

part 'wallet_state.dart';

/// The technician's wallet screen.
class WalletCubit extends Cubit<WalletState> {
  WalletCubit(this._wallets) : super(const WalletState());

  final WalletRepository _wallets;

  /// Fetches the wallet. A failed refresh keeps what is shown.
  Future<void> load() async {
    final result = await _wallets.fetch();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(WalletState(status: WalletStatus.ready, wallet: value));
      case Err():
        if (state.wallet == null) {
          emit(const WalletState(status: WalletStatus.failed));
        }
    }
  }

  /// Starts over from the spinner, after a failed first fetch.
  Future<void> retry() async {
    emit(const WalletState());
    await load();
  }
}
