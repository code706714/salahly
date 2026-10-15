import 'package:salahly/features/admin/domain/entities/admin_activity.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';

MoneySummary testMoney({int earnedPiastres = 15000}) => MoneySummary(
  earnedPiastres: earnedPiastres,
  paidInCount: 2,
  paidInPiastres: 25000,
  escrowPaidInPiastres: 10000,
  releasedToWalletsPiastres: 8000,
  withdrawals: const WithdrawalTotals(
    requestedCount: 1,
    requestedPiastres: 5000,
    paidCount: 1,
    paidPiastres: 4000,
    waitingCount: 2,
    waitingPiastres: 9000,
  ),
  transactions: [
    MoneyTransaction(
      kind: MoneyTransactionKind.packPayment,
      amountPiastres: 15000,
      at: DateTime.utc(2026, 10, 15, 9),
      personName: 'كريم',
      method: 'card',
    ),
  ],
);

ActivityReport testActivityReport() => ActivityReport(
  techniciansActive: 1,
  jobsCount: 3,
  finishedCount: 2,
  billedPiastres: 90000,
  technicians: [
    TechnicianActivity(
      id: 't1',
      name: 'كريم',
      phone: '+201001234567',
      jobsCount: 3,
      finishedCount: 2,
      customersCount: 2,
      billedPiastres: 90000,
      paidPiastres: 50000,
      jobs: [
        ActivityJob(
          id: 'j1',
          status: JobStatus.paid,
          isFromApp: true,
          totalPiastres: 60000,
          paidPiastres: 60000,
          at: DateTime.utc(2026, 10, 15, 8),
          customerName: 'منى',
          description: 'تغيير خلاط',
        ),
      ],
    ),
  ],
);
