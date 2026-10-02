import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/entities/phone_number.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';

part 'otp_state.dart';

/// Collects the one-time code, verifies it as soon as it's complete and
/// runs the resend countdown. A successful verify signs the user in; the
/// session then decides where the app goes next.
class OtpCubit extends Cubit<OtpState> {
  OtpCubit({
    required this._authRepository,
    required this.phone,
    required this.channel,
  }) : super(const OtpState()) {
    _startCountdown();
  }

  static const codeLength = 6;

  /// Matches the auth server's minimum time between two codes.
  static const resendCooldown = 60;

  final AuthRepository _authRepository;
  final PhoneNumber phone;
  final OtpChannel channel;
  Timer? _countdown;

  void digitEntered(String digit) {
    if (!_canEdit || state.isComplete) return;
    _setCode(state.code + digit);
  }

  void digitDeleted() {
    if (!_canEdit || state.code.isEmpty) return;
    _setCode(state.code.substring(0, state.code.length - 1));
  }

  /// Fills the code from pasted text such as "Your code is 123456".
  void codePasted(String text) {
    if (!_canEdit) return;
    final digits = digitsOnly(text);
    if (digits.length < codeLength) return;
    _setCode(digits.substring(0, codeLength));
  }

  Future<void> verify() async {
    if (!_canEdit || !state.isComplete) return;
    emit(state.copyWith(status: OtpStatus.verifying, failure: () => null));
    final result = await _authRepository.verifyOtp(
      phone: phone,
      code: state.code,
    );
    if (isClosed) return;
    emit(switch (result) {
      Ok() => state.copyWith(status: OtpStatus.verified),
      Err(:final failure) => state.copyWith(
        code: '',
        status: OtpStatus.entering,
        failure: () => failure,
      ),
    });
  }

  Future<void> resend() async {
    if (state.resendIn > 0 || state.isResending) return;
    emit(state.copyWith(isResending: true, failure: () => null));
    final result = await _authRepository.requestOtp(
      phone: phone,
      channel: channel,
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            isResending: false,
            resendCount: state.resendCount + 1,
            resendIn: resendCooldown,
          ),
        );
        _startCountdown();
      case Err(:final failure):
        emit(state.copyWith(isResending: false, failure: () => failure));
    }
  }

  bool get _canEdit => state.status == OtpStatus.entering;

  void _setCode(String code) {
    emit(state.copyWith(code: code, failure: () => null));
    if (state.isComplete) unawaited(verify());
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.resendIn - 1;
      emit(state.copyWith(resendIn: remaining));
      if (remaining <= 0) timer.cancel();
    });
  }

  @override
  Future<void> close() {
    _countdown?.cancel();
    return super.close();
  }
}
