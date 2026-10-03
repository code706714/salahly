import 'package:salahly/core/text/money.dart';
import 'package:salahly/features/customers/presentation/customer_labels.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/presentation/job_messages.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The polite WhatsApp reminder about everything a customer owes: the job
/// by name when there is one, else the total for "شغلانتين" or "3
/// شغلانات". [owed] must not be empty.
String customerReminderMessage(
  AppLocalizations l10n, {
  required String customerName,
  required List<JobSummary> owed,
  required String technicianName,
}) {
  if (owed.length == 1) {
    final summary = owed.single;
    return paymentReminderMessage(
      l10n,
      job: summary.job,
      customerName: customerName,
      balancePiastres: summary.balancePiastres,
      technicianName: technicianName,
    );
  }
  final total = owed.fold(0, (sum, summary) => sum + summary.balancePiastres);
  return l10n.paymentReminderMessage(
    customerName,
    formatPounds(total),
    l10n.jobCount(owed.length),
    customerGender(customerName),
    technicianName,
  );
}
