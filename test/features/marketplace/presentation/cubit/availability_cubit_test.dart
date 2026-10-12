import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/presentation/cubit/availability_cubit.dart';

import '../../../../helpers/mocks.dart';

void main() {
  late MockTechnicianRequestsRepository requests;
  final now = DateTime(2026, 10, 13, 10);
  final later = DateTime(2026, 10, 13, 14);

  setUp(() => requests = MockTechnicianRequestsRepository());

  AvailabilityCubit build() => AvailabilityCubit(requests, clock: () => now);

  blocTest<AvailabilityCubit, AvailabilityState>(
    'reads when the switch turns itself off',
    setUp: () => when(
      requests.fetchAvailability,
    ).thenAnswer((_) async => Ok(later)),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => [AvailabilityState(until: later)],
    verify: (cubit) => expect(cubit.isOn, isTrue),
  );

  blocTest<AvailabilityCubit, AvailabilityState>(
    'keeps what it had when reading fails',
    setUp: () => when(
      requests.fetchAvailability,
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => <AvailabilityState>[],
  );

  blocTest<AvailabilityCubit, AvailabilityState>(
    'switches on',
    setUp: () => when(
      () => requests.setAvailable(on: true),
    ).thenAnswer((_) async => Ok(later)),
    build: build,
    act: (cubit) => cubit.toggle(on: true),
    expect: () => [
      const AvailabilityState(isBusy: true),
      AvailabilityState(until: later),
    ],
  );

  blocTest<AvailabilityCubit, AvailabilityState>(
    'switches off',
    setUp: () => when(
      () => requests.setAvailable(on: false),
    ).thenAnswer((_) async => const Ok(null)),
    build: build,
    seed: () => AvailabilityState(until: later),
    act: (cubit) => cubit.toggle(on: false),
    expect: () => [
      AvailabilityState(until: later, isBusy: true),
      const AvailabilityState(),
    ],
  );

  blocTest<AvailabilityCubit, AvailabilityState>(
    'says when the change failed and stays as it was',
    setUp: () => when(
      () => requests.setAvailable(on: true),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (cubit) => cubit.toggle(on: true),
    expect: () => [
      const AvailabilityState(isBusy: true),
      const AvailabilityState(failure: NetworkFailure()),
    ],
  );

  test('a switch whose time passed reads as off', () {
    final state = AvailabilityState(until: later);

    expect(state.isOnAt(now), isTrue);
    expect(state.isOnAt(later), isFalse);
    expect(const AvailabilityState().isOnAt(now), isFalse);
  });
}
