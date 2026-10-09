import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/payment_due.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

String jobTagLabel(AppLocalizations l10n, JobTag tag) => switch (tag) {
  JobTag.cleaning => l10n.jobTagCleaning,
  JobTag.freon => l10n.jobTagFreon,
  JobTag.installation => l10n.jobTagInstallation,
  JobTag.notCooling => l10n.jobTagNotCooling,
  JobTag.leaking => l10n.jobTagLeaking,
  JobTag.maintenance => l10n.jobTagMaintenance,
  JobTag.removal => l10n.jobTagRemoval,
};

/// What the job is about in one line: the problems picked, "تنظيف + شحن
/// فريون", else the first line of the description.
String jobTitle(AppLocalizations l10n, Job job) {
  if (job.tags.isNotEmpty) {
    return job.tags.map((tag) => jobTagLabel(l10n, tag)).join(' + ');
  }
  final firstLine = job.description?.split('\n').first.trim() ?? '';
  return firstLine.isEmpty ? l10n.jobUntitled : firstLine;
}

String jobStatusLabel(AppLocalizations l10n, JobStatus status) =>
    switch (status) {
      JobStatus.unconfirmed => l10n.jobStatusUnconfirmed,
      JobStatus.confirmed => l10n.jobStatusConfirmed,
      JobStatus.started => l10n.jobStatusStarted,
      JobStatus.finished => l10n.jobStatusFinished,
      JobStatus.paid => l10n.jobStatusPaid,
      JobStatus.cancelled => l10n.jobStatusCancelled,
    };

/// "مستحق النهارده", "وعد يدفع السبت" or "متأخر 12 يوم".
String paymentDueLabel(
  AppLocalizations l10n,
  PaymentDue due, {
  required DateTime today,
}) => switch (due) {
  PaymentDueToday() => l10n.dueToday,
  PaymentPromised(:final day) => l10n.duePromised(
    _promiseDay(l10n, day, today),
  ),
  PaymentLate(:final days) => l10n.dueLate(days),
};

/// A promise within the week is named by its weekday, "السبت".
String _promiseDay(AppLocalizations l10n, DateTime day, DateTime today) {
  final days = CalendarDate.daysBetween(today, day);
  if (days > 1 && days < 7) return weekdayName(day);
  return dayLabel(l10n, day, today: today);
}
