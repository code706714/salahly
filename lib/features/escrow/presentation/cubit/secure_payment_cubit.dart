import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/sender_account.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/balance/domain/repositories/balance_repository.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';

part 'secure_payment_state.dart';

/// Paying a request's price to Salahly: where to transfer, where the money
/// came from and the screenshot, then sending it to be checked.
class SecurePaymentCubit extends Cubit<SecurePaymentState> {
  SecurePaymentCubit({
    required this._escrow,
    required this._balance,
    required this._photos,
    required this._requestId,
  }) : super(const SecurePaymentState());

  final EscrowRepository _escrow;
  final BalanceRepository _balance;
  final PhotoPicker _photos;
  final String _requestId;

  /// The screenshot already uploaded, by its local path, so a retry after
  /// a failed send doesn't upload it again.
  ({String local, String stored})? _uploaded;

  /// Fetches the amount and the accounts to transfer to.
  Future<void> load() async {
    emit(const SecurePaymentState());
    final result = await _escrow.fetchInfo(_requestId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final info?)
          when info.canSecure && info.accounts.isNotEmpty:
        emit(
          SecurePaymentState(
            status: SecurePaymentStatus.editing,
            amountPiastres: info.amountPiastres,
            accounts: info.accounts,
            method: info.accounts.first.method,
          ),
        );
      case Err(:final failure):
        emit(
          SecurePaymentState(
            status: SecurePaymentStatus.failed,
            failure: failure,
          ),
        );
      default:
        emit(const SecurePaymentState(status: SecurePaymentStatus.failed));
    }
  }

  void pickMethod(TopupMethod method) {
    if (state.status != SecurePaymentStatus.editing) return;
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
    final method = state.method;
    final sender = state.validSender;
    final screenshot = state.screenshot;
    if (!state.canSubmit ||
        method == null ||
        sender == null ||
        screenshot == null) {
      return;
    }
    emit(
      state.copyWith(
        status: SecurePaymentStatus.submitting,
        failure: () => null,
      ),
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
    final result = await _escrow.secure(
      requestId: _requestId,
      method: method,
      senderAccount: sender,
      screenshotPath: stored,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        _discard(screenshot);
        emit(state.copyWith(status: SecurePaymentStatus.submitted));
      case Err(:final failure):
        // The server doesn't know this upload, or it was spent: send the
        // screenshot again next time.
        if (failure is InvalidScreenshotFailure) _uploaded = null;
        _fail(failure);
    }
  }

  @override
  Future<void> close() {
    final screenshot = state.screenshot;
    if (screenshot != null && state.status != SecurePaymentStatus.submitted) {
      _discard(screenshot);
    }
    return super.close();
  }

  void _discard(String path) => unawaited(_photos.discard(path));

  void _fail(Failure failure) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: SecurePaymentStatus.editing,
        failure: () => failure,
      ),
    );
  }
}
