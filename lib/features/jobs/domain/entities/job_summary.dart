import 'package:equatable/equatable.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';

/// A job with what lists show about it: who it is for and its money.
final class JobSummary extends Equatable {
  const JobSummary({
    required this.job,
    required this.customerName,
    required this.totalPiastres,
    required this.paidPiastres,
    required this.itemCount,
    required this.isSynced,
    this.customerPhone,
    this.customerAreaId,
  });

  final Job job;
  final String customerName;
  final PhoneNumber? customerPhone;
  final String? customerAreaId;

  /// The sum of the job's lines.
  final int totalPiastres;
  final int paidPiastres;
  final int itemCount;

  /// False while some of the job's changes are only on this phone.
  final bool isSynced;

  int get balancePiastres =>
      totalPiastres > paidPiastres ? totalPiastres - paidPiastres : 0;

  /// The work is done and the customer still owes money.
  bool get awaitsPayment =>
      job.status == JobStatus.finished && balancePiastres > 0;

  @override
  List<Object?> get props => [
    job,
    customerName,
    customerPhone,
    customerAreaId,
    totalPiastres,
    paidPiastres,
    itemCount,
    isSynced,
  ];
}
