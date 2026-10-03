import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/presentation/cubit/job_details_cubit.dart';

import '../../../../helpers/job_details_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockJobsRepository jobs;
  late StreamController<JobDetails?> details;
  final today = DateTime(2026, 10, 2, 11);
  const failure = UnexpectedFailure('disk full');

  setUpAll(() => registerFallbackValue(testJob()));

  setUp(() {
    jobs = MockJobsRepository();
    details = StreamController.broadcast();
    when(() => jobs.watchJob('job-1')).thenAnswer((_) => details.stream);
  });

  tearDown(() => details.close());

  Future<JobDetailsCubit> started(JobDetails? first) async {
    final cubit = JobDetailsCubit(
      jobs: jobs,
      jobId: 'job-1',
      clock: () => today,
    )..start();
    details.add(first);
    await pumpEventQueue();
    return cubit;
  }

  group('loading', () {
    test('starts loading, dated by the clock', () {
      final cubit = JobDetailsCubit(
        jobs: jobs,
        jobId: 'job-1',
        clock: () => today,
      );
      expect(cubit.state, JobDetailsState(today: today));
      expect(cubit.state.status, JobDetailsStatus.loading);
    });

    test('shows the job and follows its changes', () async {
      final first = testDetails();
      final cubit = await started(first);
      expect(cubit.state.status, JobDetailsStatus.ready);
      expect(cubit.state.details, first);

      final second = testDetails(items: sampleItems);
      details.add(second);
      await pumpEventQueue();
      expect(cubit.state.details, second);
      await cubit.close();
    });

    test('a job never found is missing', () async {
      final cubit = await started(null);
      expect(cubit.state.status, JobDetailsStatus.missing);
      await cubit.close();
    });

    test('a job that disappears was deleted, and stays on screen', () async {
      final first = testDetails();
      final cubit = await started(first);
      details.add(null);
      await pumpEventQueue();
      expect(cubit.state.status, JobDetailsStatus.deleted);
      expect(cubit.state.details, first);
      await cubit.close();
    });
  });

  group('advance', () {
    test('moves the job on and keeps the change for undo', () async {
      final job = testJob();
      when(() => jobs.advance('job-1')).thenAnswer((_) async => Ok(job));
      final cubit = await started(testDetails(job: job));

      await cubit.advance();

      verify(() => jobs.advance('job-1')).called(1);
      expect(
        cubit.state.change,
        JobChange(previous: job, to: JobStatus.started),
      );
      expect(cubit.state.isBusy, isFalse);
      await cubit.close();
    });

    test('does nothing past the last step', () async {
      final cubit = await started(
        testDetails(job: testJob(status: JobStatus.paid)),
      );
      await cubit.advance();
      verifyNever(() => jobs.advance(any()));
      await cubit.close();
    });

    test('ignores a second tap while saving', () async {
      final job = testJob(status: JobStatus.unconfirmed);
      final saving = Completer<Result<Job>>();
      when(() => jobs.advance('job-1')).thenAnswer((_) => saving.future);
      final cubit = await started(testDetails(job: job));

      final first = cubit.advance();
      expect(cubit.state.isBusy, isTrue);
      await cubit.advance();
      saving.complete(Ok(job));
      await first;

      verify(() => jobs.advance('job-1')).called(1);
      await cubit.close();
    });

    test('reports a failure', () async {
      when(
        () => jobs.advance('job-1'),
      ).thenAnswer((_) async => const Err(failure));
      final cubit = await started(testDetails());

      await cubit.advance();

      expect(cubit.state.failure, failure);
      expect(cubit.state.change, isNull);
      expect(cubit.state.isBusy, isFalse);
      await cubit.close();
    });
  });

  group('cancel', () {
    test('cancels an open job and keeps the change for undo', () async {
      final job = testJob(status: JobStatus.started);
      when(() => jobs.cancel('job-1')).thenAnswer((_) async => Ok(job));
      final cubit = await started(testDetails(job: job));

      await cubit.cancel();

      expect(
        cubit.state.change,
        JobChange(previous: job, to: JobStatus.cancelled),
      );
      await cubit.close();
    });

    test('leaves a finished job alone', () async {
      final cubit = await started(
        testDetails(job: testJob(status: JobStatus.finished)),
      );
      await cubit.cancel();
      verifyNever(() => jobs.cancel(any()));
      await cubit.close();
    });

    test('reports a failure', () async {
      when(
        () => jobs.cancel('job-1'),
      ).thenAnswer((_) async => const Err(failure));
      final cubit = await started(testDetails());
      await cubit.cancel();
      expect(cubit.state.failure, failure);
      await cubit.close();
    });
  });

  group('undo', () {
    final previous = testJob();
    final change = JobChange(previous: previous, to: JobStatus.started);

    test('restores the job as it was and forgets the change', () async {
      when(() => jobs.advance('job-1')).thenAnswer((_) async => Ok(previous));
      when(
        () => jobs.restore(previous),
      ).thenAnswer((_) async => const Ok(null));
      final cubit = await started(testDetails(job: previous));
      await cubit.advance();

      await cubit.undo(change);

      verify(() => jobs.restore(previous)).called(1);
      expect(cubit.state.change, isNull);
      await cubit.close();
    });

    test('reports a failure and keeps the change', () async {
      when(() => jobs.advance('job-1')).thenAnswer((_) async => Ok(previous));
      when(
        () => jobs.restore(previous),
      ).thenAnswer((_) async => const Err(failure));
      final cubit = await started(testDetails(job: previous));
      await cubit.advance();

      await cubit.undo(change);

      expect(cubit.state.failure, failure);
      expect(cubit.state.change, change);
      await cubit.close();
    });
  });

  group('delete and photos', () {
    test('deletes the job', () async {
      when(
        () => jobs.deleteJob('job-1'),
      ).thenAnswer((_) async => const Ok(null));
      final cubit = await started(testDetails());
      await cubit.delete();
      verify(() => jobs.deleteJob('job-1')).called(1);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('keeps a picked photo of the work', () async {
      when(
        () => jobs.addPhoto(
          'job-1',
          kind: PhotoKind.after,
          pickedPath: '/tmp/a.jpg',
        ),
      ).thenAnswer((_) async => const Ok(null));
      final cubit = await started(testDetails());
      await cubit.addPhoto(PhotoKind.after, '/tmp/a.jpg');
      verify(
        () => jobs.addPhoto(
          'job-1',
          kind: PhotoKind.after,
          pickedPath: '/tmp/a.jpg',
        ),
      ).called(1);
      await cubit.close();
    });

    test('deletes a photo', () async {
      when(
        () => jobs.deletePhoto('photo-1'),
      ).thenAnswer((_) async => const Ok(null));
      final cubit = await started(testDetails());
      await cubit.deletePhoto('photo-1');
      verify(() => jobs.deletePhoto('photo-1')).called(1);
      await cubit.close();
    });

    test('reports a failure', () async {
      when(
        () => jobs.deletePhoto('photo-1'),
      ).thenAnswer((_) async => const Err(failure));
      final cubit = await started(testDetails());
      await cubit.deletePhoto('photo-1');
      expect(cubit.state.failure, failure);
      await cubit.close();
    });
  });
}
