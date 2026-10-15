import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/presentation/cubit/payout_account_cubit.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockEscrowRepository escrow;
  const saved = PayoutAccount(
    method: TopupMethod.wallet,
    account: '01114567720',
    holderName: 'محمود سعيد',
  );

  setUpAll(() => registerFallbackValue(saved));

  setUp(() {
    escrow = MockEscrowRepository();
    when(
      () => escrow.fetchPayoutAccount(),
    ).thenAnswer((_) async => const Ok(saved));
    when(
      () => escrow.savePayoutAccount(any()),
    ).thenAnswer((_) async => const Ok(null));
  });

  PayoutAccountCubit build() => PayoutAccountCubit(escrow);

  const editing = PayoutAccountState(
    status: PayoutAccountStatus.editing,
    account: '01114567720',
    holder: 'محمود سعيد',
  );

  group('load', () {
    blocTest<PayoutAccountCubit, PayoutAccountState>(
      'fills in the saved account',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const PayoutAccountState(), editing],
    );

    blocTest<PayoutAccountCubit, PayoutAccountState>(
      'starts empty on a wallet before one is saved',
      setUp: () => when(
        () => escrow.fetchPayoutAccount(),
      ).thenAnswer((_) async => const Ok(null)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const PayoutAccountState(),
        const PayoutAccountState(status: PayoutAccountStatus.editing),
      ],
    );

    blocTest<PayoutAccountCubit, PayoutAccountState>(
      'fails when the account can not be fetched',
      setUp: () => when(
        () => escrow.fetchPayoutAccount(),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const PayoutAccountState(),
        const PayoutAccountState(
          status: PayoutAccountStatus.failed,
          failure: NetworkFailure(),
        ),
      ],
    );
  });

  group('editing', () {
    test('saves only a valid number and a name', () {
      const empty = PayoutAccountState(status: PayoutAccountStatus.editing);
      expect(empty.canSave, isFalse);
      expect(editing.canSave, isTrue);
      expect(editing.copyWith(account: '0111').canSave, isFalse);
      expect(editing.copyWith(holder: ' م ').canSave, isFalse);
      expect(
        editing.copyWith(method: TopupMethod.instapay, account: 'ab').canSave,
        isFalse,
      );
      expect(
        editing
            .copyWith(method: TopupMethod.instapay, account: 'mahmoud@instapay')
            .canSave,
        isTrue,
      );
    });

    blocTest<PayoutAccountCubit, PayoutAccountState>(
      'saves the account as the server takes it',
      build: build,
      seed: () => editing.copyWith(
        account: '0111 456 7720',
        holder: '  محمود   سعيد ',
      ),
      act: (cubit) => cubit.save(),
      expect: () => [
        editing
            .copyWith(account: '0111 456 7720', holder: '  محمود   سعيد ')
            .copyWith(status: PayoutAccountStatus.saving),
        editing
            .copyWith(account: '0111 456 7720', holder: '  محمود   سعيد ')
            .copyWith(status: PayoutAccountStatus.saved),
      ],
      verify: (_) {
        verify(() => escrow.savePayoutAccount(saved)).called(1);
      },
    );

    blocTest<PayoutAccountCubit, PayoutAccountState>(
      'goes back to editing with the reason a save was refused',
      setUp: () => when(
        () => escrow.savePayoutAccount(any()),
      ).thenAnswer((_) async => const Err(InvalidHolderFailure())),
      build: build,
      seed: () => editing,
      act: (cubit) => cubit.save(),
      expect: () => [
        editing.copyWith(status: PayoutAccountStatus.saving),
        editing.copyWith(failure: () => const InvalidHolderFailure()),
      ],
    );

    blocTest<PayoutAccountCubit, PayoutAccountState>(
      'saves nothing while the form is not valid',
      build: build,
      seed: () => editing.copyWith(holder: ''),
      act: (cubit) => cubit.save(),
      expect: () => <PayoutAccountState>[],
    );
  });
}
