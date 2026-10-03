import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';
import 'package:salahly/features/jobs/presentation/cubit/job_details_status.dart';

export 'package:salahly/features/jobs/presentation/cubit/job_details_status.dart';

part 'job_details_state.dart';

/// One job as its page shows it, and the moves the technician makes on it:
/// its next step, cancelling, deleting and its photos.
class JobDetailsCubit extends Cubit<JobDetailsState> {
  JobDetailsCubit({
    required this._jobs,
    required this._jobId,
    DateTime Function() clock = DateTime.now,
  }) : super(JobDetailsState(today: clock()));

  final JobsRepository _jobs;
  final String _jobId;
  StreamSubscription<JobDetails?>? _subscription;

  void start() {
    _subscription = _jobs
        .watchJob(_jobId)
        .listen(_onDetails, onError: addError);
  }

  void _onDetails(JobDetails? details) {
    if (details != null) {
      emit(
        state.copyWith(
          status: JobDetailsStatus.ready,
          details: () => details,
        ),
      );
    } else {
      emit(
        state.copyWith(
          status: state.details == null
              ? JobDetailsStatus.missing
              : JobDetailsStatus.deleted,
        ),
      );
    }
  }

  /// Moves the job to its next step; the change can be taken back with
  /// [undo].
  Future<void> advance() async {
    final next = state.details?.job.status.next;
    if (next == null || state.isBusy) return;
    await _change(_jobs.advance(_jobId), next);
  }

  /// Cancels the job; the change can be taken back with [undo].
  Future<void> cancel() async {
    final job = state.details?.job;
    if (job == null || !job.status.isOpen || state.isBusy) return;
    await _change(_jobs.cancel(_jobId), JobStatus.cancelled);
  }

  Future<void> _change(Future<Result<Job>> action, JobStatus to) async {
    emit(state.copyWith(isBusy: true, failure: () => null));
    final result = await action;
    if (isClosed) return;
    emit(switch (result) {
      Ok(value: final previous) => state.copyWith(
        isBusy: false,
        change: () => JobChange(previous: previous, to: to),
      ),
      Err(:final failure) => state.copyWith(
        isBusy: false,
        failure: () => failure,
      ),
    });
  }

  /// Puts the job back the way it was before [change].
  Future<void> undo(JobChange change) async {
    emit(state.copyWith(failure: () => null));
    final result = await _jobs.restore(change.previous);
    if (isClosed) return;
    emit(switch (result) {
      Ok() => state.copyWith(change: () => null),
      Err(:final failure) => state.copyWith(failure: () => failure),
    });
  }

  /// Deletes the job; the page closes once it is gone.
  Future<void> delete() => _run(_jobs.deleteJob(_jobId));

  /// Keeps the photo picked at [path] with the job.
  Future<void> addPhoto(PhotoKind kind, String path) =>
      _run(_jobs.addPhoto(_jobId, kind: kind, pickedPath: path));

  Future<void> deletePhoto(String photoId) => _run(_jobs.deletePhoto(photoId));

  Future<void> _run(Future<Result<void>> action) async {
    emit(state.copyWith(failure: () => null));
    final result = await action;
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(state.copyWith(failure: () => failure));
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
