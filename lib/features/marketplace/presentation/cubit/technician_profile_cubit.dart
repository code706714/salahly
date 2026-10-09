import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';

part 'technician_profile_state.dart';

/// A technician's page as a consumer sees it.
class TechnicianProfileCubit extends Cubit<TechnicianProfileState> {
  TechnicianProfileCubit({
    required this._requests,
    required this._technicianId,
    this._listed = false,
    DateTime Function() clock = DateTime.now,
  }) : super(TechnicianProfileState(today: clock()));

  final ConsumerRequestsRepository _requests;
  final String _technicianId;

  /// Whether the page is the directory's, open to any verified technician,
  /// and not the one a technician's offer opens.
  final bool _listed;

  /// Fetches the page; again after a failure.
  Future<void> load() async {
    if (state.status == TechnicianProfileStatus.failed) {
      emit(
        state.copyWith(
          status: TechnicianProfileStatus.loading,
          failure: () => null,
        ),
      );
    }
    final result = _listed
        ? await _requests.fetchListedTechnician(_technicianId)
        : await _requests.fetchTechnician(_technicianId);
    if (isClosed) return;
    emit(switch (result) {
      Ok(value: final profile?) => state.copyWith(
        status: TechnicianProfileStatus.ready,
        profile: profile,
      ),
      Ok() => state.copyWith(status: TechnicianProfileStatus.notFound),
      Err(:final failure) => state.copyWith(
        status: TechnicianProfileStatus.failed,
        failure: () => failure,
      ),
    });
  }
}
