import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/arabic_search.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/text/normalize.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/repositories/customers_repository.dart';

part 'customers_state.dart';

/// The customers tab: every customer, narrowed by a filter and a search.
///
/// Follows the next day after midnight, so "النهارده" stays true.
class CustomersCubit extends Cubit<CustomersState> {
  CustomersCubit({
    required this._customers,
    List<ServiceArea> areas = const [],
    this._clock = DateTime.now,
  }) : super(
         CustomersState(
           today: CalendarDate.of(_clock()),
           areaNames: _names(areas),
         ),
       );

  final CustomersRepository _customers;
  final DateTime Function() _clock;

  StreamSubscription<List<CustomerSummary>>? _subscription;
  Timer? _midnight;

  void start() => _watchDay();

  void _watchDay() {
    final today = state.today;
    unawaited(_subscription?.cancel());
    _subscription = _customers
        .watchCustomers(today: today)
        .listen(
          (customers) => emit(state.copyWith(customers: customers)),
          onError: addError,
        );
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    _midnight?.cancel();
    _midnight = Timer(tomorrow.difference(_clock()), () {
      emit(state.copyWith(today: CalendarDate.of(_clock())));
      _watchDay();
    });
  }

  void queryChanged(String query) => emit(state.copyWith(query: query));

  void filterChanged(CustomerFilter filter) =>
      emit(state.copyWith(filter: filter));

  /// Area names are searched too; they arrive once the catalog loads.
  void areasChanged(List<ServiceArea> areas) =>
      emit(state.copyWith(areaNames: _names(areas)));

  static Map<String, String> _names(List<ServiceArea> areas) => {
    for (final area in areas) area.id: area.name,
  };

  @override
  Future<void> close() async {
    _midnight?.cancel();
    await _subscription?.cancel();
    return super.close();
  }
}
