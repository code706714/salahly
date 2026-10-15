import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/balance/domain/repositories/balance_repository.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';
import 'package:salahly/features/payments/domain/repositories/payment_repository.dart';

part 'buy_uses_state.dart';

/// Buying a pack: pick it, then pay online. The uses are added by the
/// server once the provider confirmed the payment, never by this screen.
class BuyUsesCubit extends Cubit<BuyUsesState> {
  BuyUsesCubit({
    required this._balance,
    required this._payments,
    required this._role,
  }) : super(const BuyUsesState());

  final BalanceRepository _balance;
  final PaymentRepository _payments;
  final UserRole _role;

  /// Fetches the packs and picks the one that costs the least per use.
  Future<void> load() async {
    emit(const BuyUsesState());
    switch (await _balance.fetchPacks(_role)) {
      case Ok(value: final packs) when packs.isNotEmpty:
        emit(
          BuyUsesState(
            status: BuyUsesStatus.editing,
            packs: packs,
            packId: _bestValue(packs).id,
          ),
        );
      case Err(:final failure):
        emit(BuyUsesState(status: BuyUsesStatus.failed, failure: failure));
      default:
        emit(const BuyUsesState(status: BuyUsesStatus.failed));
    }
  }

  void pickPack(String id) {
    if (state.status != BuyUsesStatus.editing) return;
    emit(state.copyWith(packId: id, failure: () => null));
  }

  /// Starts the payment of the picked pack on the server.
  Future<void> pay() async {
    final pack = state.pack;
    if (!state.canPay || pack == null) return;
    emit(state.copyWith(status: BuyUsesStatus.starting, failure: () => null));
    final result = await _payments.startCreditPackPayment(
      packId: pack.id,
      expectedPricePiastres: pack.pricePiastres,
    );
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(status: BuyUsesStatus.paying, checkout: () => value),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: BuyUsesStatus.editing,
            failure: () => failure,
          ),
        );
        if (failure is PriceChangedFailure) await _reloadPacks();
    }
  }

  /// The payment screen was closed: back to the packs.
  void paymentClosed() {
    if (state.status != BuyUsesStatus.paying) return;
    emit(state.copyWith(status: BuyUsesStatus.editing, checkout: () => null));
  }

  /// Shows the packs at their current prices.
  Future<void> _reloadPacks() async {
    final result = await _balance.fetchPacks(_role);
    if (isClosed) return;
    if (result case Ok(value: final packs) when packs.isNotEmpty) {
      emit(
        state.copyWith(
          packs: packs,
          packId: packs.any((pack) => pack.id == state.packId)
              ? state.packId
              : _bestValue(packs).id,
        ),
      );
    }
  }

  static CreditPack _bestValue(List<CreditPack> packs) => packs.reduce(
    (best, pack) => pack.perUsePiastres < best.perUsePiastres ? pack : best,
  );
}
