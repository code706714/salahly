import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/complaint_cubit.dart';

import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockConsumerRequestsRepository requests;

  setUpAll(
    () => registerFallbackValue(
      const ComplaintDraft(reason: ComplaintReason.other),
    ),
  );

  setUp(() {
    requests = MockConsumerRequestsRepository();
    when(
      () => requests.submitComplaint(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    when(
      () => requests.uploadPhoto(any()),
    ).thenAnswer((_) async => const Ok('consumer-1/photo.jpg'));
  });

  ComplaintCubit build() =>
      ComplaintCubit(requests: requests, requestId: 'request-1');

  group('load', () {
    blocTest<ComplaintCubit, ComplaintState>(
      'fetches the request for the header',
      setUp: () => when(
        () => requests.fetchRequest('request-1'),
      ).thenAnswer((_) async => Ok(testRequestDetails())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [ComplaintState(request: testRequestDetails())],
    );

    blocTest<ComplaintCubit, ComplaintState>(
      'goes on without it when it cannot be fetched',
      setUp: () => when(
        () => requests.fetchRequest('request-1'),
      ).thenAnswer((_) async => const Err(NetworkFailure())),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => const <ComplaintState>[],
    );
  });

  blocTest<ComplaintCubit, ComplaintState>(
    'picks a reason and attaches and removes a photo',
    build: build,
    act: (cubit) => cubit
      ..pickReason(ComplaintReason.poorWork)
      ..attachPhoto('/tmp/a.jpg')
      ..removePhoto(),
    expect: () => const [
      ComplaintState(reason: ComplaintReason.poorWork),
      ComplaintState(reason: ComplaintReason.poorWork, photo: '/tmp/a.jpg'),
      ComplaintState(reason: ComplaintReason.poorWork),
    ],
  );

  test('can be sent only with a reason', () {
    expect(const ComplaintState().canSend, isFalse);
    expect(
      const ComplaintState(reason: ComplaintReason.other).canSend,
      isTrue,
    );
    expect(
      const ComplaintState(
        reason: ComplaintReason.other,
        status: ComplaintStatus.sending,
      ).canSend,
      isFalse,
    );
  });

  group('send', () {
    blocTest<ComplaintCubit, ComplaintState>(
      'does nothing without a reason',
      build: build,
      act: (cubit) => cubit.send(details: 'x'),
      expect: () => const <ComplaintState>[],
      verify: (_) => verifyNever(() => requests.submitComplaint(any(), any())),
    );

    blocTest<ComplaintCubit, ComplaintState>(
      'sends the reason and the tidied details',
      build: build,
      seed: () => const ComplaintState(reason: ComplaintReason.noShowOrLate),
      act: (cubit) => cubit.send(details: '  ماجاش   خالص '),
      expect: () => const [
        ComplaintState(
          reason: ComplaintReason.noShowOrLate,
          status: ComplaintStatus.sending,
        ),
        ComplaintState(
          reason: ComplaintReason.noShowOrLate,
          status: ComplaintStatus.sent,
        ),
      ],
      verify: (_) {
        verify(
          () => requests.submitComplaint(
            'request-1',
            const ComplaintDraft(
              reason: ComplaintReason.noShowOrLate,
              details: 'ماجاش خالص',
            ),
          ),
        ).called(1);
        verifyNever(() => requests.uploadPhoto(any()));
      },
    );

    blocTest<ComplaintCubit, ComplaintState>(
      'uploads the photo first and sends its path',
      build: build,
      seed: () => const ComplaintState(
        reason: ComplaintReason.poorWork,
        photo: '/tmp/a.jpg',
      ),
      act: (cubit) => cubit.send(),
      verify: (cubit) {
        expect(cubit.state.status, ComplaintStatus.sent);
        verify(() => requests.uploadPhoto('/tmp/a.jpg')).called(1);
        verify(
          () => requests.submitComplaint(
            'request-1',
            const ComplaintDraft(
              reason: ComplaintReason.poorWork,
              photoPath: 'consumer-1/photo.jpg',
            ),
          ),
        ).called(1);
      },
    );

    blocTest<ComplaintCubit, ComplaintState>(
      'stops when the photo cannot be uploaded',
      setUp: () => when(
        () => requests.uploadPhoto(any()),
      ).thenAnswer((_) async => const Err(UploadLimitFailure())),
      build: build,
      seed: () => const ComplaintState(
        reason: ComplaintReason.poorWork,
        photo: '/tmp/a.jpg',
      ),
      act: (cubit) => cubit.send(),
      expect: () => const [
        ComplaintState(
          reason: ComplaintReason.poorWork,
          photo: '/tmp/a.jpg',
          status: ComplaintStatus.sending,
        ),
        ComplaintState(
          reason: ComplaintReason.poorWork,
          photo: '/tmp/a.jpg',
          failure: UploadLimitFailure(),
        ),
      ],
      verify: (_) => verifyNever(() => requests.submitComplaint(any(), any())),
    );

    blocTest<ComplaintCubit, ComplaintState>(
      "doesn't upload the same photo again on a retry",
      setUp: () {
        var calls = 0;
        when(() => requests.submitComplaint(any(), any())).thenAnswer(
          (_) async =>
              calls++ == 0 ? const Err(NetworkFailure()) : const Ok(null),
        );
      },
      build: build,
      seed: () => const ComplaintState(
        reason: ComplaintReason.poorWork,
        photo: '/tmp/a.jpg',
      ),
      act: (cubit) async {
        await cubit.send();
        expect(cubit.state.failure, const NetworkFailure());
        await cubit.send();
      },
      verify: (cubit) {
        expect(cubit.state.status, ComplaintStatus.sent);
        verify(() => requests.uploadPhoto('/tmp/a.jpg')).called(1);
        verify(() => requests.submitComplaint(any(), any())).called(2);
      },
    );

    blocTest<ComplaintCubit, ComplaintState>(
      'uploads a different photo picked after a failure',
      setUp: () {
        var calls = 0;
        when(() => requests.submitComplaint(any(), any())).thenAnswer(
          (_) async =>
              calls++ == 0 ? const Err(NetworkFailure()) : const Ok(null),
        );
      },
      build: build,
      seed: () => const ComplaintState(
        reason: ComplaintReason.poorWork,
        photo: '/tmp/a.jpg',
      ),
      act: (cubit) async {
        await cubit.send();
        cubit.attachPhoto('/tmp/b.jpg');
        await cubit.send();
      },
      verify: (_) {
        verify(() => requests.uploadPhoto('/tmp/a.jpg')).called(1);
        verify(() => requests.uploadPhoto('/tmp/b.jpg')).called(1);
      },
    );

    blocTest<ComplaintCubit, ComplaintState>(
      'keeps the form when a complaint is already open',
      setUp: () => when(
        () => requests.submitComplaint(any(), any()),
      ).thenAnswer((_) async => const Err(AlreadySentFailure())),
      build: build,
      seed: () => const ComplaintState(reason: ComplaintReason.other),
      act: (cubit) => cubit.send(),
      expect: () => const [
        ComplaintState(
          reason: ComplaintReason.other,
          status: ComplaintStatus.sending,
        ),
        ComplaintState(
          reason: ComplaintReason.other,
          failure: AlreadySentFailure(),
        ),
      ],
    );

    blocTest<ComplaintCubit, ComplaintState>(
      'clears the failure on the next change',
      build: build,
      seed: () => const ComplaintState(
        reason: ComplaintReason.other,
        failure: NetworkFailure(),
      ),
      act: (cubit) => cubit.pickReason(ComplaintReason.badConduct),
      expect: () => const [ComplaintState(reason: ComplaintReason.badConduct)],
    );
  });
}
