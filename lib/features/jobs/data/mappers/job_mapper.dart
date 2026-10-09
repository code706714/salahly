import 'package:drift/drift.dart' show Value;
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';

// The server's names for the domain's enums, where they differ.

const Map<JobTag, String> _tagWire = {
  JobTag.cleaning: 'cleaning',
  JobTag.freon: 'freon',
  JobTag.installation: 'installation',
  JobTag.notCooling: 'not_cooling',
  JobTag.leaking: 'leaking',
  JobTag.maintenance: 'maintenance',
  JobTag.removal: 'removal',
};
final Map<String, JobTag> _tagFromWire = {
  for (final MapEntry(:key, :value) in _tagWire.entries) value: key,
};

const Map<PaymentMethod, String> _methodWire = {
  PaymentMethod.cash: 'cash',
  PaymentMethod.instapay: 'instapay',
  PaymentMethod.vodafoneCash: 'vodafone_cash',
  PaymentMethod.other: 'other',
};
final Map<String, PaymentMethod> _methodFromWire = {
  for (final MapEntry(:key, :value) in _methodWire.entries) value: key,
};

String jobTagToWire(JobTag tag) => _tagWire[tag]!;

String paymentMethodToWire(PaymentMethod method) => _methodWire[method]!;

/// Tags this version doesn't know are left out.
List<JobTag> jobTagsFromWire(List<String> wire) => [
  for (final tag in wire) ?_tagFromWire[tag],
];

Job jobFromRow(JobRow row) => Job(
  id: row.id,
  customerId: row.customerId,
  tags: jobTagsFromWire(row.tags),
  description: row.description,
  scheduledAt: row.scheduledAt?.toLocal(),
  durationMinutes: row.durationMinutes,
  address: row.address,
  status: JobStatus.values.asNameMap()[row.status] ?? JobStatus.unconfirmed,
  confirmedAt: row.confirmedAt?.toLocal(),
  startedAt: row.startedAt?.toLocal(),
  finishedAt: row.finishedAt?.toLocal(),
  paidAt: row.paidAt?.toLocal(),
  cancelledAt: row.cancelledAt?.toLocal(),
  quoteStatus:
      QuoteStatus.values.asNameMap()[row.quoteStatus] ?? QuoteStatus.none,
  quoteSentAt: row.quoteSentAt?.toLocal(),
  quoteValidDays: row.quoteValidDays,
  paymentPromisedOn: CalendarDate.tryParse(row.paymentPromisedOn),
  invoiceNumber: row.invoiceNumber,
  source: row.source == 'platform' ? JobSource.platform : JobSource.manual,
  createdAt: row.createdAt.toLocal(),
  updatedAt: row.updatedAt.toLocal(),
);

/// [row] with the editable state of [job]; times are stored in UTC.
JobRow jobOntoRow(JobRow row, Job job, {required DateTime now}) => row.copyWith(
  tags: [for (final tag in job.tags) jobTagToWire(tag)],
  description: Value(job.description),
  scheduledAt: Value(job.scheduledAt?.toUtc()),
  durationMinutes: job.durationMinutes,
  address: Value(job.address),
  status: job.status.name,
  confirmedAt: Value(job.confirmedAt?.toUtc()),
  startedAt: Value(job.startedAt?.toUtc()),
  finishedAt: Value(job.finishedAt?.toUtc()),
  paidAt: Value(job.paidAt?.toUtc()),
  cancelledAt: Value(job.cancelledAt?.toUtc()),
  quoteStatus: job.quoteStatus.name,
  quoteSentAt: Value(job.quoteSentAt?.toUtc()),
  quoteValidDays: job.quoteValidDays,
  paymentPromisedOn: Value(
    job.paymentPromisedOn == null
        ? null
        : CalendarDate.format(job.paymentPromisedOn!),
  ),
  invoiceNumber: Value(job.invoiceNumber),
  updatedAt: now.toUtc(),
);

JobItem itemFromRow(JobItemRow row) => JobItem(
  id: row.id,
  jobId: row.jobId,
  title: row.title,
  unitPricePiastres: row.unitPricePiastres,
  quantity: row.quantity,
  sortOrder: row.sortOrder,
);

Payment paymentFromRow(PaymentRow row) => Payment(
  id: row.id,
  jobId: row.jobId,
  amountPiastres: row.amountPiastres,
  method: _methodFromWire[row.method] ?? PaymentMethod.other,
  receivedAt: row.receivedAt.toLocal(),
);

JobPhoto photoFromRow(JobPhotoRow row, LocalPhotoStore store) {
  final file = store.fileFor(row.id);
  return JobPhoto(
    id: row.id,
    jobId: row.jobId,
    kind: row.kind == 'after' ? PhotoKind.after : PhotoKind.before,
    storagePath: row.storagePath,
    localPath: file.existsSync() ? file.path : null,
    createdAt: row.createdAt.toLocal(),
  );
}
