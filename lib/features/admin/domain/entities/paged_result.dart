import 'package:equatable/equatable.dart';

/// One page of a list, with how many rows the whole list has.
final class PagedResult<T> extends Equatable {
  const PagedResult({required this.items, required this.total});

  final List<T> items;
  final int total;

  @override
  List<Object?> get props => [items, total];
}
