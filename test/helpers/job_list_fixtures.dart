import 'package:salahly/features/jobs/domain/entities/job.dart';

/// A job at any stage, with the dates the job lists sort and group by.
Job listedJob({
  String id = 'job-1',
  String customerId = 'customer-1',
  List<JobTag> tags = const [JobTag.cleaning],
  String? description,
  DateTime? scheduledAt,
  JobStatus status = JobStatus.confirmed,
  DateTime? finishedAt,
  DateTime? paidAt,
  DateTime? cancelledAt,
  QuoteStatus quoteStatus = QuoteStatus.none,
  DateTime? quoteSentAt,
  JobSource source = JobSource.manual,
  int durationMinutes = Job.defaultDurationMinutes,
}) => Job(
  id: id,
  customerId: customerId,
  tags: tags,
  description: description,
  scheduledAt: scheduledAt,
  durationMinutes: durationMinutes,
  status: status,
  finishedAt: finishedAt,
  paidAt: paidAt,
  cancelledAt: cancelledAt,
  quoteStatus: quoteStatus,
  quoteSentAt: quoteSentAt,
  source: source,
  createdAt: DateTime(2026, 9),
  updatedAt: DateTime(2026, 9),
);
