part of 'job_details_cubit.dart';

/// A step the technician just moved the job to, kept so it can be undone.
final class JobChange extends Equatable {
  const JobChange({required this.previous, required this.to});

  /// The job as it was before the change.
  final Job previous;

  /// The status the job was moved to.
  final JobStatus to;

  @override
  List<Object?> get props => [previous, to];
}

final class JobDetailsState extends Equatable {
  const JobDetailsState({
    required this.today,
    this.status = JobDetailsStatus.loading,
    this.details,
    this.isBusy = false,
    this.change,
    this.failure,
  });

  /// When the page opened, to name the visit's day.
  final DateTime today;
  final JobDetailsStatus status;

  /// The job as last loaded; kept after it is deleted.
  final JobDetails? details;

  /// A step or cancellation is being saved.
  final bool isBusy;

  /// The last step or cancellation, until undone.
  final JobChange? change;

  /// Why the last action failed.
  final Failure? failure;

  JobDetailsState copyWith({
    JobDetailsStatus? status,
    JobDetails? Function()? details,
    bool? isBusy,
    JobChange? Function()? change,
    Failure? Function()? failure,
  }) {
    return JobDetailsState(
      today: today,
      status: status ?? this.status,
      details: details != null ? details() : this.details,
      isBusy: isBusy ?? this.isBusy,
      change: change != null ? change() : this.change,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [today, status, details, isBusy, change, failure];
}
