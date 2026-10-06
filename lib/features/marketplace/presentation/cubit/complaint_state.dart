part of 'complaint_cubit.dart';

enum ComplaintStatus { editing, sending, sent }

final class ComplaintState extends Equatable {
  const ComplaintState({
    this.status = ComplaintStatus.editing,
    this.request,
    this.reason,
    this.photo,
    this.failure,
  });

  final ComplaintStatus status;

  /// The request complained about, once fetched.
  final RequestDetails? request;
  final ComplaintReason? reason;

  /// The local path of the photo to send.
  final String? photo;

  /// Why the last send failed.
  final Failure? failure;

  bool get canSend => reason != null && status == ComplaintStatus.editing;

  ComplaintState copyWith({
    ComplaintStatus? status,
    RequestDetails? request,
    ComplaintReason? reason,
    String? Function()? photo,
    Failure? Function()? failure,
  }) {
    return ComplaintState(
      status: status ?? this.status,
      request: request ?? this.request,
      reason: reason ?? this.reason,
      photo: photo != null ? photo() : this.photo,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, request, reason, photo, failure];
}
