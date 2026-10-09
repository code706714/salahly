import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/customers/domain/repositories/customers_repository.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';

part 'customer_state.dart';

/// One customer's page: their details, units, jobs and what they owe.
class CustomerCubit extends Cubit<CustomerState> {
  CustomerCubit({
    required this._customers,
    required this._jobs,
    required this._customerId,
    DateTime Function() clock = DateTime.now,
  }) : super(CustomerState(today: CalendarDate.of(clock())));

  final CustomersRepository _customers;
  final JobsRepository _jobs;
  final String _customerId;
  final _subscriptions = <StreamSubscription<Object?>>[];

  void start() {
    _subscriptions
      ..add(
        _customers
            .watchCustomer(_customerId)
            .listen(
              (record) => emit(
                record == null
                    ? state.copyWith(isGone: true)
                    : state.copyWith(record: record),
              ),
              onError: addError,
            ),
      )
      ..add(
        _jobs
            .watchCustomerJobs(_customerId)
            .listen(
              (jobs) => emit(state.copyWith(jobs: jobs)),
              onError: addError,
            ),
      );
  }

  /// Adds a unit, or changes the one with [unitId]. False when it failed;
  /// the failure is in the state.
  Future<bool> saveUnit(CustomerUnitDraft draft, {String? unitId}) => _write(
    () => unitId == null
        ? _customers.addUnit(_customerId, draft)
        : _customers.updateUnit(unitId, draft),
  );

  Future<bool> deleteUnit(String unitId) =>
      _write(() => _customers.deleteUnit(unitId));

  /// Adds a deleted [unit] back, for undo.
  Future<bool> restoreUnit(CustomerUnit unit) => saveUnit(
    CustomerUnitDraft(
      brand: unit.brand,
      capacityHp: unit.capacityHp,
      room: unit.room,
      installedYear: unit.installedYear,
      nextServiceOn: unit.nextServiceOn,
    ),
  );

  Future<bool> _write(Future<Result<void>> Function() action) async {
    if (state.failure != null) emit(state.copyWith(failure: () => null));
    final result = await action();
    if (isClosed) return result is Ok;
    switch (result) {
      case Ok():
        return true;
      case Err(:final failure):
        emit(state.copyWith(failure: () => failure));
        return false;
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    return super.close();
  }
}
