import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The WhatsApp message asking a customer to confirm a scheduled visit.
/// [job] must have a date.
String confirmationMessage(
  AppLocalizations l10n, {
  required Job job,
  required String customerName,
  required String technicianName,
  required DateTime today,
}) {
  final at = job.scheduledAt!;
  return l10n.jobConfirmationMessage(
    customerName,
    dayLabel(l10n, at, today: today),
    clockTime(at),
    partOfDayLabel(l10n, PartOfDay.of(at)),
    jobTitle(l10n, job),
    technicianName,
  );
}

/// The polite WhatsApp reminder about money still owed for [job].
String paymentReminderMessage(
  AppLocalizations l10n, {
  required Job job,
  required String customerName,
  required int balancePiastres,
  required String technicianName,
}) => l10n.paymentReminderMessage(
  customerName,
  formatPounds(balancePiastres),
  jobTitle(l10n, job),
  hasFeminineTitle(customerName) ? 'female' : 'male',
  technicianName,
);
