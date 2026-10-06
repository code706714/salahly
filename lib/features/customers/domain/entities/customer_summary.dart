import 'package:equatable/equatable.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';

/// A customer with what the list shows about them.
final class CustomerSummary extends Equatable {
  const CustomerSummary({
    required this.customer,
    required this.jobCount,
    required this.unitCount,
    required this.owedPiastres,
    this.owedSince,
    this.lastFinishedAt,
    this.nextScheduledAt,
    this.nextServiceOn,
  });

  final Customer customer;

  /// Jobs, not counting cancelled ones.
  final int jobCount;
  final int unitCount;

  /// What the customer owes for finished work.
  final int owedPiastres;

  /// When the oldest unpaid job was finished.
  final DateTime? owedSince;
  final DateTime? lastFinishedAt;

  /// The next visit still to happen, from today on.
  final DateTime? nextScheduledAt;

  /// The soonest next service of their units, a calendar date at local
  /// midnight; may be past when overdue.
  final DateTime? nextServiceOn;

  @override
  List<Object?> get props => [
    customer,
    jobCount,
    unitCount,
    owedPiastres,
    owedSince,
    lastFinishedAt,
    nextScheduledAt,
    nextServiceOn,
  ];
}

/// A customer and their air conditioners.
final class CustomerRecord extends Equatable {
  const CustomerRecord({
    required this.customer,
    required this.units,
    this.bookedInApp = false,
  });

  final Customer customer;
  final List<CustomerUnit> units;

  /// Has a job booked through the app. Such jobs stay on the server, so
  /// the customer can't be deleted.
  final bool bookedInApp;

  @override
  List<Object?> get props => [customer, units, bookedInApp];
}
