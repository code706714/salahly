import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';

part 'technician_directory_state.dart';

/// The technicians a consumer can browse, filtered by trade and area and
/// ordered by one of five measures. A page of technicians at a time.
class TechnicianDirectoryCubit extends Cubit<TechnicianDirectoryState> {
  TechnicianDirectoryCubit(this._requests)
    : super(const TechnicianDirectoryState());

  final ConsumerRequestsRepository _requests;

  /// Counts the lists asked for, so an answer to an older filter is dropped.
  int _generation = 0;

  /// Fetches the first page again with the filters as they are.
  Future<void> load() async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: state.technicians.isEmpty
            ? TechnicianDirectoryStatus.loading
            : state.status,
        failure: () => null,
      ),
    );
    final result = await _requests.browseTechnicians(
      categoryId: state.categoryId,
      areaId: state.areaId,
      sort: state.sort,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            status: TechnicianDirectoryStatus.ready,
            technicians: value,
            hasMore: value.length >= technicianPageSize,
          ),
        );
      case Err(:final failure):
        emit(
          state.copyWith(
            status: state.technicians.isEmpty
                ? TechnicianDirectoryStatus.failed
                : TechnicianDirectoryStatus.ready,
            failure: () => failure,
          ),
        );
    }
  }

  /// Shows one trade, or all of them for null.
  Future<void> selectCategory(String? categoryId) {
    emit(state.copyWith(categoryId: () => categoryId, technicians: const []));
    return load();
  }

  /// Shows the technicians covering one area, or any for null.
  Future<void> selectArea(String? areaId) {
    emit(state.copyWith(areaId: () => areaId, technicians: const []));
    return load();
  }

  Future<void> selectSort(TechnicianSort sort) {
    emit(state.copyWith(sort: sort, technicians: const []));
    return load();
  }

  /// Fetches the next page and adds it to the list.
  Future<void> loadMore() async {
    if (!state.hasMore ||
        state.loadingMore ||
        state.status != TechnicianDirectoryStatus.ready) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    final result = await _requests.browseTechnicians(
      categoryId: state.categoryId,
      areaId: state.areaId,
      sort: state.sort,
      offset: state.technicians.length,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        emit(
          state.copyWith(
            technicians: [...state.technicians, ...value],
            hasMore: value.length >= technicianPageSize,
            loadingMore: false,
          ),
        );
      case Err(:final failure):
        // The list stays as it is; scrolling to the end tries again.
        emit(state.copyWith(loadingMore: false, failure: () => failure));
    }
  }
}
