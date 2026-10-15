import 'package:equatable/equatable.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';

/// What a money movement was.
enum MoneyTransactionKind {
  /// A technician bought uses; this is what the app earned.
  packPayment,

  /// A consumer paid for a job, held with the app until the work is
  /// confirmed.
  escrowPayment,

  /// A technician asked to take money out of their wallet.
  withdrawalRequested,
  withdrawalPaid,
  withdrawalRejected,
}

/// One payment or withdrawal.
final class MoneyTransaction extends Equatable {
  const MoneyTransaction({
    required this.kind,
    required this.amountPiastres,
    required this.at,
    this.personName,
    this.method,
  });

  final MoneyTransactionKind kind;
  final int amountPiastres;
  final DateTime at;

  /// Null when the account was deleted.
  final String? personName;

  /// How it was paid or where it goes, as the server names it.
  final String? method;

  @override
  List<Object?> get props => [kind, amountPiastres, at, personName, method];
}

/// What technicians asked to take out of their wallets.
final class WithdrawalTotals extends Equatable {
  const WithdrawalTotals({
    required this.requestedCount,
    required this.requestedPiastres,
    required this.paidCount,
    required this.paidPiastres,
    required this.waitingCount,
    required this.waitingPiastres,
  });

  /// Asked for in the period.
  final int requestedCount;
  final int requestedPiastres;

  /// Paid by the team in the period.
  final int paidCount;
  final int paidPiastres;

  /// Still waiting for the team, whenever they were asked for.
  final int waitingCount;
  final int waitingPiastres;

  @override
  List<Object?> get props => [
    requestedCount,
    requestedPiastres,
    paidCount,
    paidPiastres,
    waitingCount,
    waitingPiastres,
  ];
}

/// The money of one period: what came in, what the app earned and what went
/// out to technicians.
final class MoneySummary extends Equatable {
  const MoneySummary({
    required this.earnedPiastres,
    required this.paidInCount,
    required this.paidInPiastres,
    required this.escrowPaidInPiastres,
    required this.releasedToWalletsPiastres,
    required this.withdrawals,
    required this.transactions,
  });

  /// What the app itself earned: the uses technicians bought.
  final int earnedPiastres;

  /// Everything paid online.
  final int paidInCount;
  final int paidInPiastres;

  /// The part of it that is a job's price, held for the technician.
  final int escrowPaidInPiastres;

  /// Moved into technicians' wallets.
  final int releasedToWalletsPiastres;
  final WithdrawalTotals withdrawals;

  /// Newest first.
  final List<MoneyTransaction> transactions;

  @override
  List<Object?> get props => [
    earnedPiastres,
    paidInCount,
    paidInPiastres,
    escrowPaidInPiastres,
    releasedToWalletsPiastres,
    withdrawals,
    transactions,
  ];
}

/// One job a technician worked on, as the team sees it.
final class ActivityJob extends Equatable {
  const ActivityJob({
    required this.id,
    required this.status,
    required this.isFromApp,
    required this.totalPiastres,
    required this.paidPiastres,
    required this.at,
    this.customerName,
    this.description,
  });

  final String id;

  final JobStatus status;

  /// Whether it came through the app's marketplace, not the technician's own
  /// customers.
  final bool isFromApp;
  final int totalPiastres;
  final int paidPiastres;
  final DateTime at;
  final String? customerName;
  final String? description;

  @override
  List<Object?> get props => [
    id,
    status,
    isFromApp,
    totalPiastres,
    paidPiastres,
    at,
    customerName,
    description,
  ];
}

/// What one technician did in the period.
final class TechnicianActivity extends Equatable {
  const TechnicianActivity({
    required this.id,
    required this.jobsCount,
    required this.finishedCount,
    required this.customersCount,
    required this.billedPiastres,
    required this.paidPiastres,
    required this.jobs,
    this.name,
    this.phone,
  });

  final String id;
  final String? name;
  final String? phone;
  final int jobsCount;
  final int finishedCount;
  final int customersCount;

  /// What the finished jobs came to, and what customers paid on all of them.
  final int billedPiastres;
  final int paidPiastres;

  /// The latest ones, newest first.
  final List<ActivityJob> jobs;

  @override
  List<Object?> get props => [
    id,
    name,
    phone,
    jobsCount,
    finishedCount,
    customersCount,
    billedPiastres,
    paidPiastres,
    jobs,
  ];
}

/// Every technician who worked in the period, busiest first.
final class ActivityReport extends Equatable {
  const ActivityReport({
    required this.techniciansActive,
    required this.jobsCount,
    required this.finishedCount,
    required this.billedPiastres,
    required this.technicians,
  });

  final int techniciansActive;
  final int jobsCount;
  final int finishedCount;
  final int billedPiastres;
  final List<TechnicianActivity> technicians;

  @override
  List<Object?> get props => [
    techniciansActive,
    jobsCount,
    finishedCount,
    billedPiastres,
    technicians,
  ];
}
