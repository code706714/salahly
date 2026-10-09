import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';

/// How many rows a page of any admin list holds. The server allows up to
/// 100.
const adminPageSize = 25;

/// One page of a filtered list, as the page shows it.
final class PagedState<T, F> extends Equatable {
  const PagedState({
    required this.filter,
    this.items = const [],
    this.total = 0,
    this.page = 0,
    this.isLoading = true,
    this.failure,
  });

  final F filter;

  /// The rows of the current page; the previous page's stay in place while
  /// the next one loads.
  final List<T> items;

  /// How many rows the whole filtered list has.
  final int total;

  /// The current page, counted from 0.
  final int page;
  final bool isLoading;

  /// Why the last load failed, if it did.
  final Failure? failure;

  int get pageCount => math.max(1, (total / adminPageSize).ceil());

  bool get hasPrevious => page > 0;

  bool get hasNext => page + 1 < pageCount;

  /// Whether there is nothing to show and nothing is on the way.
  bool get isEmpty => items.isEmpty && !isLoading && failure == null;

  PagedState<T, F> copyWith({
    F? filter,
    List<T>? items,
    int? total,
    int? page,
    bool? isLoading,
    Failure? Function()? failure,
  }) {
    return PagedState(
      filter: filter ?? this.filter,
      items: items ?? this.items,
      total: total ?? this.total,
      page: page ?? this.page,
      isLoading: isLoading ?? this.isLoading,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [filter, items, total, page, isLoading, failure];
}

/// A list the admin filters and pages through, fetched from the server a
/// page at a time. An answer that arrives after a newer request was made
/// is dropped.
abstract class PagedCubit<T, F> extends Cubit<PagedState<T, F>> {
  PagedCubit(F filter) : super(PagedState(filter: filter));

  int _generation = 0;

  @protected
  Future<Result<PagedResult<T>>> fetch(
    F filter, {
    required int limit,
    required int offset,
  });

  Future<void> load() => _load(state.page);

  /// Shows the first page of the list narrowed to [filter].
  Future<void> filterChanged(F filter) {
    if (filter == state.filter) return Future.value();
    emit(state.copyWith(filter: filter));
    return _load(0);
  }

  Future<void> goToPage(int page) {
    if (page < 0 || page >= state.pageCount) return Future.value();
    return _load(page);
  }

  /// Fetches the current page again, for instance after an item was
  /// reviewed and left the list.
  Future<void> reload() => _load(state.page);

  Future<void> _load(int page) async {
    final generation = ++_generation;
    emit(state.copyWith(page: page, isLoading: true, failure: () => null));
    final result = await fetch(
      state.filter,
      limit: adminPageSize,
      offset: page * adminPageSize,
    );
    if (isClosed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        final pageCount = math.max(1, (value.total / adminPageSize).ceil());
        if (value.items.isEmpty && page >= pageCount) {
          // The page this was on is gone: its last row left the list.
          await _load(pageCount - 1);
          return;
        }
        emit(
          state.copyWith(
            items: value.items,
            total: value.total,
            isLoading: false,
          ),
        );
      case Err(:final failure):
        emit(state.copyWith(isLoading: false, failure: () => failure));
    }
  }
}
