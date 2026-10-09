import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/admin/domain/repositories/overview_repository.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';

part 'admin_session_state.dart';

/// Whether the console may be used: someone is signed in and the server
/// accepts them as an admin. The server is the only judge; the console
/// asks it once after every sign in, and every later call is checked again
/// there.
class AdminSessionCubit extends Cubit<AdminSessionState> {
  AdminSessionCubit({
    required this._authRepository,
    required this._overviewRepository,
  }) : super(const AdminSessionChecking()) {
    _subscription = _authRepository.userChanges.listen(_onUserChanged);
  }

  final AuthRepository _authRepository;
  final OverviewRepository _overviewRepository;
  late final StreamSubscription<AuthUser?> _subscription;
  int _generation = 0;
  String? _checkedUserId;

  /// Asks the server again, after the check could not be made.
  Future<void> retry() => _check(_checkedUserId);

  /// Leaves the no-access screen for the sign-in screen.
  void leaveNoAccess() {
    if (state is AdminSessionNoAccess) emit(const AdminSessionSignedOut());
  }

  /// Signs out of the console.
  Future<void> signOut() => _authRepository.signOut();

  Future<void> _onUserChanged(AuthUser? user) {
    if (user == null) {
      _generation++;
      // The no-access screen outlives the sign out that comes with it.
      if (state is! AdminSessionNoAccess) emit(const AdminSessionSignedOut());
      return Future.value();
    }
    // The same person signing in anew (to repeat a money change) is already
    // checked.
    if (state is AdminSessionReady && user.id == _checkedUserId) {
      return Future.value();
    }
    return _check(user.id);
  }

  Future<void> _check(String? userId) async {
    final generation = ++_generation;
    _checkedUserId = userId;
    emit(const AdminSessionChecking());
    final result = await _overviewRepository.fetchOverview(
      OverviewPeriod.today,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok():
        emit(const AdminSessionReady());
      case Err(failure: AdminRequiredFailure()):
        emit(const AdminSessionNoAccess());
        await _authRepository.signOut();
      case Err(:final failure):
        emit(AdminSessionUnavailable(failure));
    }
  }

  @override
  Future<void> close() {
    unawaited(_subscription.cancel());
    return super.close();
  }
}
