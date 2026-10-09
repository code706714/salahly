import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/presentation/cubit/technician_profile_cubit.dart';

import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockConsumerRequestsRepository requests;
  final today = DateTime(2026, 10, 6, 9);
  final profile = testTechnicianProfile();

  setUp(() => requests = MockConsumerRequestsRepository());

  TechnicianProfileCubit build() => TechnicianProfileCubit(
    requests: requests,
    technicianId: 'tech-1',
    clock: () => today,
  );

  test('starts loading, dated today', () async {
    final cubit = build();

    expect(cubit.state, TechnicianProfileState(today: today));
    expect(cubit.state.status, TechnicianProfileStatus.loading);
    await cubit.close();
  });

  test('shows the technician', () async {
    when(
      () => requests.fetchTechnician('tech-1'),
    ).thenAnswer((_) async => Ok(profile));
    final cubit = build();

    await cubit.load();

    expect(
      cubit.state,
      TechnicianProfileState(
        today: today,
        status: TechnicianProfileStatus.ready,
        profile: profile,
      ),
    );
    await cubit.close();
  });

  test('reads a technician from the directory by what is listed', () async {
    when(
      () => requests.fetchListedTechnician('tech-1'),
    ).thenAnswer((_) async => Ok(profile));
    final cubit = TechnicianProfileCubit(
      requests: requests,
      technicianId: 'tech-1',
      clock: () => today,
      listed: true,
    );

    await cubit.load();

    expect(cubit.state.profile, profile);
    verifyNever(() => requests.fetchTechnician(any()));
    await cubit.close();
  });

  test('says when the technician is gone', () async {
    when(
      () => requests.fetchTechnician('tech-1'),
    ).thenAnswer((_) async => const Ok(null));
    final cubit = build();

    await cubit.load();

    expect(cubit.state.status, TechnicianProfileStatus.notFound);
    expect(cubit.state.profile, isNull);
    await cubit.close();
  });

  test('fails, then loads again on retry', () async {
    when(
      () => requests.fetchTechnician('tech-1'),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = build();

    await cubit.load();
    expect(cubit.state.status, TechnicianProfileStatus.failed);
    expect(cubit.state.failure, const NetworkFailure());

    when(
      () => requests.fetchTechnician('tech-1'),
    ).thenAnswer((_) async => Ok(profile));
    final states = <TechnicianProfileState>[];
    final subscription = cubit.stream.listen(states.add);
    await cubit.load();
    await Future<void>.delayed(Duration.zero);

    expect(states.map((state) => state.status), [
      TechnicianProfileStatus.loading,
      TechnicianProfileStatus.ready,
    ]);
    expect(states.first.failure, isNull);
    expect(cubit.state.profile, profile);
    await subscription.cancel();
    await cubit.close();
  });

  test('ignores an answer that comes after the page closed', () async {
    when(
      () => requests.fetchTechnician('tech-1'),
    ).thenAnswer((_) async => Ok(profile));
    final cubit = build();

    final loading = cubit.load();
    await cubit.close();
    await loading;

    expect(cubit.state.status, TechnicianProfileStatus.loading);
  });
}
