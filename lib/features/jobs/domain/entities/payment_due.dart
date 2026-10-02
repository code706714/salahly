import 'package:equatable/equatable.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';

/// Where a finished job's unpaid money stands, as the technician thinks of
/// it: due today, promised for a day, or late by some days.
sealed class PaymentDue extends Equatable {
  const PaymentDue();

  /// Money is due from the day the job was finished, or from the day the
  /// customer promised once that day has passed. [today] is any time on
  /// the local day to judge by.
  factory PaymentDue.of(Job job, {required DateTime today}) {
    final day = CalendarDate.of(today);
    final promised = job.paymentPromisedOn;
    if (promised != null && !promised.isBefore(day)) {
      return PaymentPromised(promised);
    }
    final since = promised ?? job.finishedAt ?? job.updatedAt;
    final days = CalendarDate.daysBetween(since, day);
    return days <= 0 ? const PaymentDueToday() : PaymentLate(days);
  }

  /// Days late, zero when not late, for ordering who to remind first.
  int get daysLate => switch (this) {
    PaymentLate(:final days) => days,
    PaymentDueToday() || PaymentPromised() => 0,
  };

  @override
  List<Object?> get props => [];
}

final class PaymentDueToday extends PaymentDue {
  const PaymentDueToday();
}

/// The customer promised to pay on [day], today or later.
final class PaymentPromised extends PaymentDue {
  const PaymentPromised(this.day);

  /// Local midnight.
  final DateTime day;

  @override
  List<Object?> get props => [day];
}

final class PaymentLate extends PaymentDue {
  const PaymentLate(this.days);

  final int days;

  @override
  List<Object?> get props => [days];
}
