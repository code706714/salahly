import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/repositories/account_repository.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';

part 'session_state.dart';

/// Who is using the app right now, which decides every redirect.
///
/// A cached profile is shown immediately so the app opens offline, then
/// refreshed from the server in the background.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required this._authRepository,
    required this._accountRepository,
  }) : super(const SessionLoading()) {
    _subscription = _authRepository.userChanges.listen(_onUserChanged);
  }

  final AuthRepository _authRepository;
  final AccountRepository _accountRepository;
  late final StreamSubscription<AuthUser?> _subscription;

  /// Fetches the profile again, e.g. after onboarding or to retry.
  Future<void> refreshProfile() async {
    final user = _authRepository.currentUser;
    if (user != null) await _loadProfile(user);
  }

  Future<void> signOut() => _authRepository.signOut();

  Future<void> _onUserChanged(AuthUser? user) async {
    if (user == null) {
      await _accountRepository.clearCache();
      if (!isClosed && _authRepository.currentUser == null) {
        emit(const SessionSignedOut());
      }
      return;
    }
    final cached = await _accountRepository.cachedProfile(user.id);
    if (isClosed) return;
    if (cached != null && _isCurrent(user)) {
      emit(SessionReady(user: user, profile: cached));
    }
    await _loadProfile(user);
  }

  Future<void> _loadProfile(AuthUser user) async {
    final result = await _accountRepository.fetchProfile(user.id);
    // The user may have signed out while the request was in flight.
    if (isClosed || !_isCurrent(user)) return;
    switch (result) {
      case Ok(value: final profile?):
        emit(SessionReady(user: user, profile: profile));
      case Ok():
        emit(SessionNeedsOnboarding(user));
      case Err():
        // Keep showing this user's cached profile when there is one.
        if (state case SessionReady(user: final shown) when shown == user) {
          return;
        }
        emit(SessionProfileUnavailable(user));
    }
  }

  bool _isCurrent(AuthUser user) => _authRepository.currentUser == user;

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
