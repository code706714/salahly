import 'package:equatable/equatable.dart';

/// Where a job stands, in the order the work happens.
enum JobStatus {
  unconfirmed,
  confirmed,
  started,
  finished,
  paid,
  cancelled;

  /// The step the job's main button moves to, or null when there is none.
  /// Moving from finished to paid happens by recording the payment.
  JobStatus? get next => switch (this) {
    unconfirmed => confirmed,
    confirmed => started,
    started => finished,
    finished || paid || cancelled => null,
  };

  /// Still ahead of the technician: not done and not cancelled.
  bool get isOpen =>
      this == unconfirmed || this == confirmed || this == started;

  /// The work is done; only the money may be pending.
  bool get isDone => this == finished || this == paid;
}

enum QuoteStatus { none, draft, sent, accepted }

/// The problems a technician picks from when writing down a job.
enum JobTag {
  cleaning,
  freon,
  installation,
  notCooling,
  leaking,
  maintenance,
  removal,
}

enum JobSource { manual, platform }

final class Job extends Equatable {
  const Job({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.description,
    this.scheduledAt,
    this.durationMinutes = defaultDurationMinutes,
    this.address,
    this.status = JobStatus.unconfirmed,
    this.confirmedAt,
    this.startedAt,
    this.finishedAt,
    this.paidAt,
    this.cancelledAt,
    this.quoteStatus = QuoteStatus.none,
    this.quoteSentAt,
    this.quoteValidDays = defaultQuoteValidDays,
    this.paymentPromisedOn,
    this.invoiceNumber,
    this.source = JobSource.manual,
  });

  static const defaultDurationMinutes = 60;
  static const defaultQuoteValidDays = 3;
  static const maxDescriptionLength = 1000;

  final String id;
  final String customerId;
  final List<JobTag> tags;
  final String? description;

  /// Local time; null while the visit has no date yet.
  final DateTime? scheduledAt;
  final int durationMinutes;

  /// Where the work is, when it differs from the customer's address.
  final String? address;
  final JobStatus status;
  final DateTime? confirmedAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final DateTime? paidAt;
  final DateTime? cancelledAt;
  final QuoteStatus quoteStatus;
  final DateTime? quoteSentAt;
  final int quoteValidDays;

  /// The day the customer promised to pay, at local midnight.
  final DateTime? paymentPromisedOn;
  final int? invoiceNumber;
  final JobSource source;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  List<Object?> get props => [
    id,
    customerId,
    tags,
    description,
    scheduledAt,
    durationMinutes,
    address,
    status,
    confirmedAt,
    startedAt,
    finishedAt,
    paidAt,
    cancelledAt,
    quoteStatus,
    quoteSentAt,
    quoteValidDays,
    paymentPromisedOn,
    invoiceNumber,
    source,
    createdAt,
    updatedAt,
  ];
}

/// A new job as entered in the form.
final class JobDraft extends Equatable {
  const JobDraft({
    required this.customerId,
    this.tags = const [],
    this.description,
    this.scheduledAt,
    this.durationMinutes = Job.defaultDurationMinutes,
    this.address,
  });

  final String customerId;
  final List<JobTag> tags;
  final String? description;
  final DateTime? scheduledAt;
  final int durationMinutes;
  final String? address;

  @override
  List<Object?> get props => [
    customerId,
    tags,
    description,
    scheduledAt,
    durationMinutes,
    address,
  ];
}
