import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';

part 'consumer_home_state.dart';

/// The consumer's start screen: the category the request button asks for,
/// and how many technicians cover each open category in their area.
class ConsumerHomeCubit extends Cubit<ConsumerHomeState> {
  ConsumerHomeCubit({required this._requests, required this._areaId})
    : super(const ConsumerHomeState());

  final ConsumerRequestsRepository _requests;

  /// The consumer's area; null while signing out.
  final String? _areaId;

  /// Categories whose count is being fetched.
  final _counting = <String>{};

  /// Takes the catalog's categories: keeps the pick while its category is
  /// still open, else picks the first open one, and counts the technicians
  /// of open categories not counted yet.
  void useCategories(List<ServiceCategory> categories) {
    final open = [
      for (final category in categories)
        if (category.isActive) category.id,
    ];
    final selectedId = open.contains(state.selectedId)
        ? state.selectedId
        : open.firstOrNull;
    emit(state.copyWith(categories: categories, selectedId: () => selectedId));
    for (final id in open) {
      if (!state.technicianCounts.containsKey(id)) unawaited(_count(id));
    }
  }

  /// Picks the category the request button asks for; only open ones can be
  /// picked.
  void select(String categoryId) {
    if (state.category(categoryId)?.isActive ?? false) {
      emit(state.copyWith(selectedId: () => categoryId));
    }
  }

  /// Counts the technicians of every open category again.
  Future<void> refresh() => Future.wait([
    for (final category in state.categories)
      if (category.isActive) _count(category.id),
  ]);

  Future<void> _count(String categoryId) async {
    final areaId = _areaId;
    if (areaId == null || !_counting.add(categoryId)) return;
    final result = await _requests.availableTechnicianCount(
      categoryId: categoryId,
      areaId: areaId,
    );
    _counting.remove(categoryId);
    if (isClosed) return;
    // A count that couldn't be fetched stays as it was; refresh tries again.
    if (result case Ok(:final value)) {
      emit(
        state.copyWith(
          technicianCounts: {...state.technicianCounts, categoryId: value},
        ),
      );
    }
  }
}
