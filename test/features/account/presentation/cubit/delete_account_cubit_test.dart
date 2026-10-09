import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/account/presentation/cubit/delete_account_cubit.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockAccountRepository account;

  setUp(() => account = MockAccountRepository());

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'deletes the account',
    setUp: () =>
        when(account.deleteAccount).thenAnswer((_) async => const Ok(null)),
    build: () => DeleteAccountCubit(account),
    act: (cubit) => cubit.delete(),
    expect: () => const [
      DeleteAccountState(status: DeleteAccountStatus.deleting),
      DeleteAccountState(status: DeleteAccountStatus.deleted),
    ],
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'keeps the failure, so the screen can say why',
    setUp: () => when(
      account.deleteAccount,
    ).thenAnswer((_) async => const Err(PendingTransferFailure())),
    build: () => DeleteAccountCubit(account),
    act: (cubit) => cubit.delete(),
    expect: () => const [
      DeleteAccountState(status: DeleteAccountStatus.deleting),
      DeleteAccountState(
        status: DeleteAccountStatus.failed,
        failure: PendingTransferFailure(),
      ),
    ],
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'can try again after a failure',
    setUp: () => when(
      account.deleteAccount,
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: () => DeleteAccountCubit(account),
    act: (cubit) async {
      await cubit.delete();
      await cubit.delete();
    },
    verify: (_) => verify(account.deleteAccount).called(2),
  );

  blocTest<DeleteAccountCubit, DeleteAccountState>(
    'does not delete twice at once or after it is done',
    setUp: () =>
        when(account.deleteAccount).thenAnswer((_) async => const Ok(null)),
    build: () => DeleteAccountCubit(account),
    act: (cubit) async {
      final first = cubit.delete();
      await cubit.delete();
      await first;
      await cubit.delete();
    },
    verify: (_) => verify(account.deleteAccount).called(1),
  );
}
