import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';

part 'open_requests_state.dart';

/// Every open request in the technician's trades and areas, newest first,
/// whether or not it was sent to them. A page at a time, for one trade or
/// all of them.
class OpenRequestsCubit extends Cubit<OpenRequestsState> {
  OpenRequestsCubit(this._requests) : super(const OpenRequestsState());

  final TechnicianRequestsRepository _requests;

  /// Counts the lists asked for, so an answer to an older filter is dropped.
  int _generation = 0;

  /// Fetches the first page again with the trade as it is.
  Future<void> load() async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: state.requests.isEmpty
            ? OpenRequestsStatus.loading
            : state.status,
        failure: () => null,
      ),
    );
    final result = await _requests.browseOpenRequests(
      categoryId: state.categoryId,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: OpenRequestsStatus.ready,
            requests: value,
            hasMore: value.length >= openRequestsPageSize,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: state.requests.isEmpty
                ? OpenRequestsStatus.failed
                : OpenRequestsStatus.ready,
            failure: () => failure,
          ),
        );
    }
  }

  /// Shows one trade, or all of them for null.
  Future<void> selectCategory(String? categoryId) {
    emit(state.copyWith(categoryId: () => categoryId, requests: const []));
    return load();
  }

  /// Fetches the next page and adds it to the list.
  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.loadingMore ||
        state.status != OpenRequestsStatus.ready) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    final result = await _requests.browseOpenRequests(
      categoryId: state.categoryId,
      offset: state.requests.length,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            requests: [...state.requests, ...value],
            hasMore: value.length >= openRequestsPageSize,
            loadingMore: false,
          ),
        );
      case Err(:final failure):
        // The list stays as it is; scrolling to the end tries again.
        emit(state.copyWith(loadingMore: false, failure: () => failure));
    }
  }
}
