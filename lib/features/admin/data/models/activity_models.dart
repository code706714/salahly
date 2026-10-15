import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/admin_activity.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';

/// Maps what `admin_money_summary` and `admin_technician_activity` return.
abstract final class ActivityModels {
  static MoneySummary money(Map<String, dynamic> json) {
    final paidIn = json['paid_in'] as Map<String, dynamic>;
    final withdrawals = json['withdrawals'] as Map<String, dynamic>;
    return MoneySummary(
      earnedPiastres: intOf(json['earned_piastres']),
      paidInCount: intOf(paidIn['count']),
      paidInPiastres: intOf(paidIn['total_piastres']),
      escrowPaidInPiastres: intOf(paidIn['escrow_piastres']),
      releasedToWalletsPiastres: intOf(json['released_to_wallets_piastres']),
      withdrawals: WithdrawalTotals(
        requestedCount: intOf(withdrawals['requested_count']),
        requestedPiastres: intOf(withdrawals['requested_piastres']),
        paidCount: intOf(withdrawals['paid_count']),
        paidPiastres: intOf(withdrawals['paid_piastres']),
        waitingCount: intOf(withdrawals['waiting_count']),
        waitingPiastres: intOf(withdrawals['waiting_piastres']),
      ),
      transactions: [
        for (final item in listFromWire(json['transactions']))
          MoneyTransaction(
            kind: enumFromWire(MoneyTransactionKind.values, item['kind']),
            amountPiastres: intOf(item['amount_piastres']),
            at: timeFromWire(item['at']),
            personName: item['person_name'] as String?,
            method: item['method'] as String?,
          ),
      ],
    );
  }

  static ActivityReport activity(Map<String, dynamic> json) => ActivityReport(
    techniciansActive: intOf(json['technicians_active']),
    jobsCount: intOf(json['jobs_count']),
    finishedCount: intOf(json['finished_count']),
    billedPiastres: intOf(json['billed_piastres']),
    technicians: [
      for (final technician in listFromWire(json['technicians']))
        TechnicianActivity(
          id: technician['id'] as String,
          name: technician['name'] as String?,
          phone: technician['phone'] as String?,
          jobsCount: intOf(technician['jobs_count']),
          finishedCount: intOf(technician['finished_count']),
          customersCount: intOf(technician['customers_count']),
          billedPiastres: intOf(technician['billed_piastres']),
          paidPiastres: intOf(technician['paid_piastres']),
          jobs: [
            for (final job in listFromWire(technician['jobs']))
              ActivityJob(
                id: job['id'] as String,
                status: enumFromWire(JobStatus.values, job['status']),
                isFromApp: job['source'] == 'platform',
                totalPiastres: intOf(job['total_piastres']),
                paidPiastres: intOf(job['paid_piastres']),
                at: timeFromWire(job['at']),
                customerName: job['customer_name'] as String?,
                description: job['description'] as String?,
              ),
          ],
        ),
    ],
  );
}
