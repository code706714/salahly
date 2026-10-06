import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/sender_account.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/balance/domain/repositories/balance_repository.dart';

part 'buy_uses_state.dart';

/// Buying a pack: the pack, where the money goes, where it came from and
/// the screenshot, then sending it for review.
class BuyUsesCubit extends Cubit<BuyUsesState> {
  BuyUsesCubit({
    required this._balance,
    required this._photos,
    required this._role,
  }) : super(const BuyUsesState());

  final BalanceRepository _balance;
  final PhotoPicker _photos;
  final UserRole _role;

  /// The screenshot already uploaded, by its local path, so a retry after
  /// a failed submit doesn't upload it again.
  ({String local, String stored})? _uploaded;

  /// Fetches the packs and the accounts to transfer to, and picks the pack
  /// that costs the least per use and the first method on offer.
  Future<void> load() async {
    emit(const BuyUsesState());
    final results = await (
      _balance.fetchPacks(_role),
      _balance.fetchPaymentAccounts(),
    ).wait;
    if (isClosed) return;
    switch (results) {
      case (Ok(value: final packs), Ok(value: final accounts))
          when packs.isNotEmpty && accounts.isNotEmpty:
        emit(
          BuyUsesState(
            status: BuyUsesStatus.editing,
            packs: packs,
            accounts: accounts,
            packId: _bestValue(packs).id,
            method: TopupMethod.values
                .where((m) => accounts.any((a) => a.method == m))
                .first,
          ),
        );
      case (Err(:final failure), _) || (_, Err(:final failure)):
        emit(BuyUsesState(status: BuyUsesStatus.failed, failure: failure));
      default:
        emit(const BuyUsesState(status: BuyUsesStatus.failed));
    }
  }

  void pickPack(String id) {
    if (state.status != BuyUsesStatus.editing) return;
    emit(state.copyWith(packId: id, failure: () => null));
  }

  void pickMethod(TopupMethod method) {
    if (state.status != BuyUsesStatus.editing) return;
    emit(state.copyWith(method: method, failure: () => null));
  }

  void setSender(String sender) {
    if (sender == state.sender) return;
    emit(state.copyWith(sender: sender, failure: () => null));
  }

  /// [path] is a screenshot the `PhotoPicker` already cleaned. The one it
  /// replaces is deleted: it is a bank screenshot.
  void attachScreenshot(String path) {
    final replaced = state.screenshot;
    if (replaced != null && replaced != path) _discard(replaced);
    emit(state.copyWith(screenshot: () => path, failure: () => null));
  }

  /// Uploads the screenshot, then says the transfer was made.
  Future<void> submit() async {
    final pack = state.pack;
    final method = state.method;
    final sender = state.validSender;
    final screenshot = state.screenshot;
    if (!state.canSubmit ||
        pack == null ||
        method == null ||
        sender == null ||
        screenshot == null) {
      return;
    }
    emit(
      state.copyWith(status: BuyUsesStatus.submitting, failure: () => null),
    );
    var stored = _uploaded?.local == screenshot ? _uploaded?.stored : null;
    if (stored == null) {
      switch (await _balance.uploadScreenshot(screenshot)) {
        case Ok(:final value):
          stored = value;
          _uploaded = (local: screenshot, stored: value);
        case Err(:final failure):
          _fail(failure);
          return;
      }
    }
    if (isClosed) return;
    final result = await _balance.submitTopup(
      packId: pack.id,
      expectedPricePiastres: pack.pricePiastres,
      method: method,
      senderAccount: sender,
      screenshotPath: stored,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        _discard(screenshot);
        emit(state.copyWith(status: BuyUsesStatus.submitted));
      case Err(:final failure):
        // The server doesn't know this upload, or it was spent: send the
        // screenshot again next time.
        if (failure is InvalidScreenshotFailure) _uploaded = null;
        _fail(failure);
        if (failure is PriceChangedFailure) await _reloadPacks();
    }
  }

  /// Shows the packs at their current prices, keeping the rest of the form.
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

  @override
  Future<void> close() {
    final screenshot = state.screenshot;
    if (screenshot != null && state.status != BuyUsesStatus.submitted) {
      _discard(screenshot);
    }
    return super.close();
  }

  void _discard(String path) => unawaited(_photos.discard(path));

  void _fail(Failure failure) {
    if (isClosed) return;
    emit(
      state.copyWith(status: BuyUsesStatus.editing, failure: () => failure),
    );
  }

  static CreditPack _bestValue(List<CreditPack> packs) => packs.reduce(
    (best, pack) => pack.perUsePiastres < best.perUsePiastres ? pack : best,
  );
}
