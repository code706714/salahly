import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/storage/user_scoped_data.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/repositories/account_repository.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';

part 'session_state.dart';

/// Who is using the app right now, which decides every redirect.
///
/// A cached profile is shown immediately so the app opens offline, then
/// refreshed from the server in the background. Data kept on the phone
/// belongs to the signed-in user only: it is deleted on sign-out and before
/// another user's session starts.
class SessionCubit extends Cubit<SessionState> {
  SessionCubit({
    required this._authRepository,
    required this._accountRepository,
    required this._userData,
  }) : super(const SessionLoading()) {
    _subscription = _authRepository.userChanges.listen(_onUserChanged);
  }

  final AuthRepository _authRepository;
  final AccountRepository _accountRepository;
  final UserScopedData _userData;
  late final StreamSubscription<AuthUser?> _subscription;

  /// Fetches the profile again, e.g. after onboarding or to retry.
  Future<void> refreshProfile() async {
    final user = _authRepository.currentUser;
    if (user != null) await _loadProfile(user);
  }

  Future<void> signOut() => _authRepository.signOut();

  ({String userId, String location})? _returnTo;

  /// Signs out so the person can sign in again, and brings them back to
  /// [location] once they are signed in as the same user.
  Future<void> signOutAndReturnTo(String location) async {
    final user = _authRepository.currentUser;
    if (user != null) _returnTo = (userId: user.id, location: location);
    try {
      await signOut();
    } on Object {
      _returnTo = null;
      rethrow;
    }
  }

  /// Where to send [user] now that they signed in again, once; null when
  /// they didn't sign out to come back somewhere.
  String? takeReturnTo(AuthUser user) {
    final target = _returnTo;
    if (target == null) return null;
    _returnTo = null;
    return target.userId == user.id ? target.location : null;
  }

  /// Signs out after the account was deleted. The account is gone whatever
  /// happens here, so a failure (no network) is reported and the data on
  /// the phone is erased all the same.
  Future<void> signOutDeleted() async {
    try {
      await signOut();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      await _accountRepository.clearCache();
      await _guard(_userData.clear);
    }
  }

  Future<void> _onUserChanged(AuthUser? user) async {
    if (user == null) {
      await _accountRepository.clearCache();
      await _guard(_userData.clear);
      if (!isClosed && _authRepository.currentUser == null) {
        emit(const SessionSignedOut());
      }
      return;
    }
    await _guard(() => _userData.claimFor(user.id));
    if (isClosed) return;
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

  /// A storage failure must not lock the user out; it is reported instead.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    return super.close();
  }
}
