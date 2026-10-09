import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';

/// What a change the admin made did, for the message the page shows.
enum AdminOutcome {
  verificationApproved,
  verificationRejected,
  topupApproved,
  topupRejected,
  complaintResolved,
  userSuspended,
  userRestored,
  settingsSaved,
  packAdded,
  areaSaved,
}

/// Where the admin's last change to the server stands.
final class ActionState extends Equatable {
  const ActionState({
    this.isBusy = false,
    this.completed = 0,
    this.outcome,
    this.failure,
  });

  /// A change is on its way; another one is not started meanwhile.
  final bool isBusy;

  /// How many changes went through, so a page can react to each one.
  final int completed;

  /// What the last change that went through did.
  final AdminOutcome? outcome;

  /// Why the last change failed, if it did.
  final Failure? failure;

  ActionState copyWith({
    bool? isBusy,
    int? completed,
    AdminOutcome? outcome,
    Failure? Function()? failure,
  }) {
    return ActionState(
      isBusy: isBusy ?? this.isBusy,
      completed: completed ?? this.completed,
      outcome: outcome ?? this.outcome,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [isBusy, completed, outcome, failure];
}

/// Runs changes the admin makes one at a time, and remembers the last one
/// so it can run again after the admin signs in anew (see
/// `RecentLoginRequiredFailure`).
class ActionCubit extends Cubit<ActionState> {
  ActionCubit() : super(const ActionState());

  Future<Result<void>> Function()? _last;
  AdminOutcome? _lastOutcome;

  /// Runs [action] unless another is running.
  Future<void> perform(
    Future<Result<void>> Function() action, {
    required AdminOutcome outcome,
  }) async {
    if (state.isBusy) return;
    _last = action;
    _lastOutcome = outcome;
    emit(state.copyWith(isBusy: true, failure: () => null));
    final result = await action();
    if (isClosed) return;
    emit(switch (result) {
      Ok() => state.copyWith(
        isBusy: false,
        completed: state.completed + 1,
        outcome: outcome,
      ),
      Err(:final failure) => state.copyWith(
        isBusy: false,
        failure: () => failure,
      ),
    });
  }

  /// Runs the last change again.
  Future<void> retry() {
    final last = _last;
    final outcome = _lastOutcome;
    return last == null || outcome == null
        ? Future.value()
        : perform(last, outcome: outcome);
  }

  /// Forgets the last failure, once the page has shown it.
  void dismissFailure() => emit(state.copyWith(failure: () => null));
}
