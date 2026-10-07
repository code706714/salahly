import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_actions_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_form_cubit.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';

import '../../../../helpers/admin_fixtures.dart';
import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  setUpAll(AdminHarness.registerFallbacks);

  group('SettingsCubit', () {
    late MockSettingsRepository settings;
    late MockOverviewRepository overview;

    setUp(() {
      settings = MockSettingsRepository();
      overview = MockOverviewRepository();
      when(
        () => settings.fetchSettings(),
      ).thenAnswer((_) async => Ok(testSettings()));
      when(
        () => overview.fetchAreas(
          any(),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((_) async => Ok(testCoverage()));
    });

    SettingsCubit build() => SettingsCubit(
      settingsRepository: settings,
      overviewRepository: overview,
    );

    blocTest<SettingsCubit, SettingsState>(
      'loads the settings with the areas',
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const SettingsState(),
        SettingsState(
          settings: testSettings(),
          coverage: testCoverage(),
          isLoading: false,
        ),
      ],
    );

    blocTest<SettingsCubit, SettingsState>(
      'says why the settings could not load',
      setUp: () => when(
        () => settings.fetchSettings(),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      verify: (cubit) {
        expect(cubit.state.failure, const NetworkFailure());
        expect(cubit.state.settings, isNull);
      },
    );
  });

  group('SettingsFormCubit', () {
    SettingsFormCubit build([AdminSettings? settings]) =>
        SettingsFormCubit(settings ?? testSettings());

    test('starts from what is saved, with nothing to save', () {
      final cubit = build();
      addTearDown(cubit.close);

      expect(cubit.state.hasChanges, isFalse);
      expect(cubit.state.isValid, isTrue);
      expect(cubit.state.consumerFreeRequests, 3);
      expect(cubit.state.packPrices['pack-c5'], 8000);
    });

    test('keeps free uses between 0 and the most a new account gets', () {
      final cubit = build();
      addTearDown(cubit.close);

      cubit.consumerFreeRequestsChanged(-4);
      expect(cubit.state.consumerFreeRequests, 0);
      cubit.technicianFreeJobsChanged(500);
      expect(
        cubit.state.technicianFreeJobs,
        SettingsFormCubit.maxFreeUses,
      );
      expect(cubit.state.freeUsesChanged, isTrue);
    });

    test('takes a launch target between 1 and 100,000', () {
      final cubit = build();
      addTearDown(cubit.close);

      cubit.targetChanged('250');
      expect(cubit.state.verifiedTechnicianTarget, 250);
      expect(cubit.state.isValid, isTrue);

      for (final invalid in ['', '0', 'abc', '100001']) {
        cubit.targetChanged(invalid);
        expect(cubit.state.verifiedTechnicianTarget, isNull, reason: invalid);
        expect(cubit.state.isValid, isFalse, reason: invalid);
      }
    });

    test('takes prices of 1 to 1,000,000 pounds, also in Arabic digits', () {
      final cubit = build();
      addTearDown(cubit.close);

      cubit.packPriceChanged('pack-c5', '٩٠');
      expect(cubit.state.packPrices['pack-c5'], 9000);

      for (final invalid in ['', '0', 'x', '1000001']) {
        cubit.packPriceChanged('pack-c5', invalid);
        expect(cubit.state.packPrices['pack-c5'], isNull, reason: invalid);
        expect(cubit.state.isValid, isFalse, reason: invalid);
      }
    });

    test('finds the packs that changed, switched on ones first', () {
      final settings = AdminSettings(
        consumerFreeRequests: 3,
        technicianFreeJobs: 5,
        verifiedTechnicianTarget: 100,
        packs: const [
          CreditPackSetting(
            id: 'a',
            role: UserRole.consumer,
            uses: 5,
            pricePiastres: 8000,
            sortOrder: 1,
            isActive: true,
          ),
          CreditPackSetting(
            id: 'b',
            role: UserRole.consumer,
            uses: 10,
            pricePiastres: 15000,
            sortOrder: 2,
            isActive: false,
          ),
        ],
        paymentAccounts: testSettings().paymentAccounts,
      );
      final cubit = build(settings);
      addTearDown(cubit.close);

      cubit
        ..packActiveChanged('a', isActive: false)
        ..packActiveChanged('b', isActive: true)
        ..packPriceChanged('b', '160');

      expect(cubit.state.changedPacks.map((pack) => pack.id), ['b', 'a']);
      expect(cubit.state.changedPacks.first.pricePiastres, 16000);
      expect(cubit.state.changedPacks.first.isActive, isTrue);
    });

    test('leaves an untouched pack out', () {
      final cubit = build();
      addTearDown(cubit.close);

      cubit
        ..packPriceChanged('pack-c5', '90')
        ..packPriceChanged('pack-c5', '80');

      expect(cubit.state.changedPacks, isEmpty);
      expect(cubit.state.hasChanges, isFalse);
    });

    test('finds the accounts that changed and blocks a blank one', () {
      final cubit = build();
      addTearDown(cubit.close);

      cubit
        ..accountChanged(TopupMethod.wallet, account: '01111111111')
        ..accountChanged(TopupMethod.wallet, isActive: true);

      expect(cubit.state.changedAccounts, hasLength(1));
      expect(cubit.state.changedAccounts.single.account, '01111111111');
      expect(cubit.state.changedAccounts.single.isActive, isTrue);
      expect(cubit.state.isValid, isTrue);

      cubit.accountChanged(TopupMethod.instapay, holderName: '  ');
      expect(cubit.state.isValid, isFalse);
    });
  });

  group('SettingsActionsCubit', () {
    late MockSettingsRepository repository;

    setUp(() {
      repository = MockSettingsRepository();
      when(
        () => repository.updateFreeUses(
          consumerFreeRequests: any(named: 'consumerFreeRequests'),
          technicianFreeJobs: any(named: 'technicianFreeJobs'),
          verifiedTechnicianTarget: any(named: 'verifiedTechnicianTarget'),
        ),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => repository.saveCreditPack(any()),
      ).thenAnswer((_) async => const Ok(null));
      when(
        () => repository.updatePaymentAccount(any()),
      ).thenAnswer((_) async => const Ok(null));
    });

    SettingsFormCubit form() {
      final cubit = SettingsFormCubit(testSettings());
      addTearDown(cubit.close);
      return cubit;
    }

    test(
      'saves only what changed, free uses first, then packs, then accounts',
      () async {
        final edit = form()
          ..consumerFreeRequestsChanged(4)
          ..packPriceChanged('pack-t10', '300')
          ..accountChanged(TopupMethod.instapay, account: 'new@instapay');
        final cubit = SettingsActionsCubit(repository);
        addTearDown(cubit.close);

        await cubit.save(edit.state);

        verifyInOrder([
          () => repository.updateFreeUses(
            consumerFreeRequests: 4,
            technicianFreeJobs: 5,
            verifiedTechnicianTarget: 100,
          ),
          () => repository.saveCreditPack(
            const CreditPackDraft(
              id: 'pack-t10',
              role: UserRole.technician,
              uses: 10,
              pricePiastres: 30000,
              sortOrder: 1,
            ),
          ),
          () => repository.updatePaymentAccount(
            const PaymentAccountSetting(
              method: TopupMethod.instapay,
              account: 'new@instapay',
              holderName: 'صلحلي',
              isActive: true,
            ),
          ),
        ]);
        verifyNoMoreInteractions(repository);
        expect(cubit.state.outcome, AdminOutcome.settingsSaved);
        expect(cubit.state.completed, 1);
      },
    );

    test('sends nothing for what did not change', () async {
      final edit = form()..packPriceChanged('pack-t10', '300');
      final cubit = SettingsActionsCubit(repository);
      addTearDown(cubit.close);

      await cubit.save(edit.state);

      verifyNever(
        () => repository.updateFreeUses(
          consumerFreeRequests: any(named: 'consumerFreeRequests'),
          technicianFreeJobs: any(named: 'technicianFreeJobs'),
          verifiedTechnicianTarget: any(named: 'verifiedTechnicianTarget'),
        ),
      );
      verifyNever(() => repository.updatePaymentAccount(any()));
      verify(() => repository.saveCreditPack(any())).called(1);
    });

    test('stops at the first change the server refuses', () async {
      when(
        () => repository.updateFreeUses(
          consumerFreeRequests: any(named: 'consumerFreeRequests'),
          technicianFreeJobs: any(named: 'technicianFreeJobs'),
          verifiedTechnicianTarget: any(named: 'verifiedTechnicianTarget'),
        ),
      ).thenAnswer((_) async => const Err(RecentLoginRequiredFailure()));
      final edit = form()
        ..consumerFreeRequestsChanged(4)
        ..packPriceChanged('pack-t10', '300');
      final cubit = SettingsActionsCubit(repository);
      addTearDown(cubit.close);

      await cubit.save(edit.state);

      expect(cubit.state.failure, const RecentLoginRequiredFailure());
      verifyNever(() => repository.saveCreditPack(any()));
    });

    test('saves again after a fresh sign in, with the same values', () async {
      var signedInRecently = false;
      when(() => repository.saveCreditPack(any())).thenAnswer(
        (_) async => signedInRecently
            ? const Ok(null)
            : const Err(RecentLoginRequiredFailure()),
      );
      final edit = form()..packPriceChanged('pack-t10', '300');
      final cubit = SettingsActionsCubit(repository);
      addTearDown(cubit.close);

      await cubit.save(edit.state);
      signedInRecently = true;
      await cubit.retry();

      expect(cubit.state.completed, 1);
      verify(() => repository.saveCreditPack(any())).called(2);
    });

    blocTest<SettingsActionsCubit, ActionState>(
      'adds a pack',
      build: () => SettingsActionsCubit(repository),
      act: (cubit) => cubit.addPack(
        const CreditPackDraft(
          role: UserRole.consumer,
          uses: 20,
          pricePiastres: 30000,
        ),
      ),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.packAdded),
      ],
    );

    blocTest<SettingsActionsCubit, ActionState>(
      'saves an area',
      setUp: () => when(
        () => repository.saveArea(any()),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => SettingsActionsCubit(repository),
      act: (cubit) => cubit.saveArea(
        const AreaDraft(
          id: 'maadi',
          name: 'المعادي',
          city: 'القاهرة',
          centerLat: 29.96,
          centerLng: 31.25,
        ),
      ),
      expect: () => const [
        ActionState(isBusy: true),
        ActionState(completed: 1, outcome: AdminOutcome.areaSaved),
      ],
    );

    blocTest<SettingsActionsCubit, ActionState>(
      'closes an area for new requests',
      setUp: () => when(
        () => repository.setAreaOpen(any(), isOpen: any(named: 'isOpen')),
      ).thenAnswer((_) async => const Ok(null)),
      build: () => SettingsActionsCubit(repository),
      act: (cubit) => cubit.setAreaOpen('shubra', isOpen: false),
      verify: (_) => verify(
        () => repository.setAreaOpen('shubra', isOpen: false),
      ).called(1),
    );
  });
}
