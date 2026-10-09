import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/text/normalize.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';

part 'complaint_state.dart';

/// A complaint about one request: why, in the consumer's words, with an
/// optional photo.
class ComplaintCubit extends Cubit<ComplaintState> {
  ComplaintCubit({required this._requests, required this._requestId})
    : super(const ComplaintState());

  final ConsumerRequestsRepository _requests;
  final String _requestId;

  /// The photo already uploaded, by its local path, so a retry after a
  /// failed send doesn't upload it again.
  ({String local, String stored})? _uploaded;

  /// Fetches the request for the header. The complaint can be sent
  /// without it.
  Future<void> load() async {
    final result = await _requests.fetchRequest(_requestId);
    if (isClosed) return;
    if (result case Ok(value: final request?)) {
      emit(state.copyWith(request: request));
    }
  }

  void pickReason(ComplaintReason reason) =>
      emit(state.copyWith(reason: reason, failure: () => null));

  /// [path] is a photo the `PhotoPicker` already cleaned.
  void attachPhoto(String path) =>
      emit(state.copyWith(photo: () => path, failure: () => null));

  void removePhoto() =>
      emit(state.copyWith(photo: () => null, failure: () => null));

  /// Uploads the photo if there is one, then sends the complaint.
  Future<void> send({String? details}) async {
    final reason = state.reason;
    if (reason == null || state.status != ComplaintStatus.editing) return;
    emit(
      state.copyWith(status: ComplaintStatus.sending, failure: () => null),
    );
    final photo = state.photo;
    String? stored;
    if (photo != null) {
      stored = _uploaded?.local == photo ? _uploaded?.stored : null;
      if (stored == null) {
        switch (await _requests.uploadPhoto(photo)) {
          case Ok(:final value):
            stored = value;
            _uploaded = (local: photo, stored: value);
          case Err(:final failure):
            _fail(failure);
            return;
        }
      }
    }
    final result = await _requests.submitComplaint(
      _requestId,
      ComplaintDraft(
        reason: reason,
        details: normalizeText(details),
        photoPath: stored,
      ),
    );
    if (isClosed) return;
    switch (result) {
      case Ok():
        emit(state.copyWith(status: ComplaintStatus.sent));
      case Err(:final failure):
        _fail(failure);
    }
  }

  void _fail(Failure failure) {
    if (isClosed) return;
    emit(
      state.copyWith(status: ComplaintStatus.editing, failure: () => failure),
    );
  }
}
