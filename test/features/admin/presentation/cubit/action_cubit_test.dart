import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';

void main() {
  blocTest<ActionCubit, ActionState>(
    'shows busy, then counts the change and says what it did',
    build: ActionCubit.new,
    act: (cubit) => cubit.perform(
      () async => const Ok(null),
      outcome: AdminOutcome.userSuspended,
    ),
    expect: () => const [
      ActionState(isBusy: true),
      ActionState(completed: 1, outcome: AdminOutcome.userSuspended),
    ],
  );

  blocTest<ActionCubit, ActionState>(
    'reports why the server refused',
    build: ActionCubit.new,
    act: (cubit) => cubit.perform(
      () async => const Err(NetworkFailure()),
      outcome: AdminOutcome.userSuspended,
    ),
    expect: () => const [
      ActionState(isBusy: true),
      ActionState(failure: NetworkFailure()),
    ],
  );

  test('starts no second change while one is on its way', () async {
    final cubit = ActionCubit();
    addTearDown(cubit.close);
    final gate = Completer<Result<void>>();
    var calls = 0;

    final first = cubit.perform(() {
      calls++;
      return gate.future;
    }, outcome: AdminOutcome.topupApproved);
    await cubit.perform(() async {
      calls++;
      return const Ok(null);
    }, outcome: AdminOutcome.topupApproved);
    gate.complete(const Ok(null));
    await first;

    expect(calls, 1);
    expect(cubit.state.completed, 1);
  });

  test('repeats the last change, which a fresh sign in then allows', () async {
    final cubit = ActionCubit();
    addTearDown(cubit.close);
    var signedInRecently = false;
    Future<Result<void>> approve() async => signedInRecently
        ? const Ok(null)
        : const Err(RecentLoginRequiredFailure());

    await cubit.perform(approve, outcome: AdminOutcome.topupApproved);
    expect(cubit.state.failure, const RecentLoginRequiredFailure());

    signedInRecently = true;
    await cubit.retry();

    expect(cubit.state.failure, isNull);
    expect(cubit.state.completed, 1);
    expect(cubit.state.outcome, AdminOutcome.topupApproved);
  });

  blocTest<ActionCubit, ActionState>(
    'has nothing to repeat before a change was made',
    build: ActionCubit.new,
    act: (cubit) => cubit.retry(),
    expect: () => <Object>[],
  );

  blocTest<ActionCubit, ActionState>(
    'forgets a failure once the page has shown it',
    build: ActionCubit.new,
    seed: () => const ActionState(failure: NetworkFailure()),
    act: (cubit) => cubit.dismissFailure(),
    expect: () => const [ActionState()],
  );
}
