import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';

/// A job with sensible defaults; override what a test is about.
Job testJob({
  String id = 'job-1',
  String customerId = 'customer-1',
  List<JobTag> tags = const [JobTag.cleaning],
  String? description,
  DateTime? scheduledAt,
  int durationMinutes = Job.defaultDurationMinutes,
  String? address,
  JobStatus status = JobStatus.confirmed,
  DateTime? finishedAt,
  QuoteStatus quoteStatus = QuoteStatus.none,
  DateTime? paymentPromisedOn,
  int? invoiceNumber,
  JobSource source = JobSource.manual,
}) => Job(
  id: id,
  customerId: customerId,
  tags: tags,
  description: description,
  scheduledAt: scheduledAt,
  durationMinutes: durationMinutes,
  address: address,
  status: status,
  finishedAt: finishedAt,
  quoteStatus: quoteStatus,
  paymentPromisedOn: paymentPromisedOn,
  invoiceNumber: invoiceNumber,
  source: source,
  createdAt: DateTime(2026, 10),
  updatedAt: DateTime(2026, 10),
);

/// A job as lists show it.
JobSummary testSummary(
  Job job, {
  String customerName = 'أ. كريم منصور',
  String? customerPhone = '01228703314',
  String? customerAreaId,
  String? customerAddress,
  int totalPiastres = 0,
  int paidPiastres = 0,
  int itemCount = 0,
  bool isSynced = true,
}) => JobSummary(
  job: job,
  customerName: customerName,
  customerPhone: customerPhone == null
      ? null
      : PhoneNumber.tryParse(customerPhone),
  customerAreaId: customerAreaId,
  customerAddress: customerAddress,
  totalPiastres: totalPiastres,
  paidPiastres: paidPiastres,
  itemCount: itemCount,
  isSynced: isSynced,
);
