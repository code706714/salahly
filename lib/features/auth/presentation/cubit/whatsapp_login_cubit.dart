import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/whatsapp_login.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';

part 'whatsapp_login_state.dart';

/// Signs in with a WhatsApp message: gets a code, opens WhatsApp with it
/// ready to send, then asks the server every few seconds whether the
/// message arrived. A successful sign in changes the session, which moves
/// the app on; nothing here navigates.
class WhatsappLoginCubit extends Cubit<WhatsappLoginState> {
  WhatsappLoginCubit({
    required this._authRepository,
    required this._externalApps,
    this.onlyFor,
    this.pollInterval = const Duration(seconds: 3),
  }) : super(const WhatsappLoginState());

  final AuthRepository _authRepository;
  final ExternalApps _externalApps;
  final Duration pollInterval;

  /// When set, only this number may sign in; any other is signed out again.
  final PhoneNumber? onlyFor;

  Timer? _poll;
  var _isPolling = false;
  var _message = '';

  /// Asks for a code and opens WhatsApp; [messageFor] writes the message
  /// that carries it.
  Future<void> start(String Function(String code) messageFor) async {
    if (state.phase != WhatsappLoginPhase.idle &&
        state.phase != WhatsappLoginPhase.expired) {
      return;
    }
    emit(
      const WhatsappLoginState(phase: WhatsappLoginPhase.starting),
    );
    final result = await _authRepository.startWhatsappLogin();
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        _message = messageFor(value.code);
        emit(
          WhatsappLoginState(
            phase: WhatsappLoginPhase.waiting,
            challenge: value,
          ),
        );
        _poll = Timer.periodic(pollInterval, (_) => unawaited(_check()));
        await openWhatsapp();
      case Err(:final failure):
        emit(WhatsappLoginState(failure: failure));
    }
  }

  /// Opens the chat again, e.g. when the first try was closed.
  Future<void> openWhatsapp() async {
    final challenge = state.challenge;
    if (challenge == null || state.phase != WhatsappLoginPhase.waiting) return;
    final opened = await _externalApps.whatsApp(
      text: _message,
      to: challenge.whatsappNumber,
    );
    if (isClosed) return;
    emit(state.copyWith(couldNotOpenWhatsapp: !opened));
  }

  /// Gives up waiting and goes back to the start.
  void cancel() {
    if (state.phase != WhatsappLoginPhase.waiting) return;
    _stopPolling();
    emit(const WhatsappLoginState());
  }

  Future<void> _check() async {
    final challenge = state.challenge;
    if (_isPolling || state.phase != WhatsappLoginPhase.waiting) return;
    if (challenge == null) return;
    _isPolling = true;
    try {
      final result = await _authRepository.whatsappLoginProgress(challenge);
      if (isClosed || state.phase != WhatsappLoginPhase.waiting) return;
      switch (result) {
        case Ok(value: WhatsappLoginProgress.ready):
          await _complete(challenge);
        case Ok(value: WhatsappLoginProgress.expired):
          _expire();
        case Ok() || Err():
          // Still waiting, or the network blinked; the next check tells.
          if (!DateTime.now().isBefore(challenge.expiresAt)) _expire();
      }
    } finally {
      _isPolling = false;
    }
  }

  Future<void> _complete(WhatsappLoginChallenge challenge) async {
    _stopPolling();
    emit(
      WhatsappLoginState(
        phase: WhatsappLoginPhase.signingIn,
        challenge: challenge,
      ),
    );
    final result = await _authRepository.completeWhatsappLogin(challenge);
    if (isClosed) return;
    switch (result) {
      case Ok():
        if (_isOtherNumber()) {
          await _authRepository.signOut();
          if (isClosed) return;
          emit(
            const WhatsappLoginState(
              failure: WhatsappLoginWrongNumberFailure(),
            ),
          );
          return;
        }
        // The session change moves the app on; keep the spinner until then.
        emit(
          WhatsappLoginState(
            phase: WhatsappLoginPhase.signedIn,
            challenge: challenge,
          ),
        );
      case Err(failure: WhatsappLoginExpiredFailure()):
        _expire();
      case Err(:final failure):
        emit(WhatsappLoginState(failure: failure));
    }
  }

  bool _isOtherNumber() {
    final expected = onlyFor;
    if (expected == null) return false;
    final signedIn = PhoneNumber.tryParse(
      _authRepository.currentUser?.phone ?? '',
    );
    return signedIn?.e164 != expected.e164;
  }

  void _expire() {
    _stopPolling();
    emit(const WhatsappLoginState(phase: WhatsappLoginPhase.expired));
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  @override
  Future<void> close() {
    _stopPolling();
    return super.close();
  }
}
