import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';

import 'job_fixtures.dart';

/// A customer with sensible defaults; override what a test is about.
Customer testCustomer({
  String id = 'customer-1',
  String name = 'م. شريف عادل',
  String? phone = '01002345678',
  String? areaId = 'heliopolis',
  String? address = '12 شارع الأهرام',
}) => Customer(
  id: id,
  name: name,
  phone: phone == null ? null : PhoneNumber.tryParse(phone),
  areaId: areaId,
  address: address,
  createdAt: DateTime(2026, 9),
);

JobItem testItem(
  String title,
  int unitPounds, {
  int quantity = 1,
  String? id,
  String jobId = 'job-1',
}) => JobItem(
  id: id ?? 'item-$title',
  jobId: jobId,
  title: title,
  unitPricePiastres: unitPounds * 100,
  quantity: quantity,
);

Payment testPayment(
  int pounds, {
  PaymentMethod method = PaymentMethod.cash,
  DateTime? receivedAt,
  String id = 'payment-1',
}) => Payment(
  id: id,
  jobId: 'job-1',
  amountPiastres: pounds * 100,
  method: method,
  receivedAt: receivedAt ?? DateTime(2026, 10, 2, 15),
);

JobPhoto testPhoto({
  String id = 'photo-1',
  PhotoKind kind = PhotoKind.before,
  String? localPath,
}) => JobPhoto(
  id: id,
  jobId: 'job-1',
  kind: kind,
  storagePath: 'user-1/$id.jpg',
  localPath: localPath,
  createdAt: DateTime(2026, 10, 2, 12),
);

/// The design's sample lines: 900 + 4 × 100 + 150 = 1,450.
final List<JobItem> sampleItems = [
  testItem('تركيب وحدة سبليت 2.25 حصان', 900),
  testItem('ماسورة نحاس زيادة (المتر)', 100, quantity: 4),
  testItem('حامل للوحدة الخارجية', 150),
];

/// One job with what its screens show.
JobDetails testDetails({
  Job? job,
  Customer? customer,
  List<JobItem> items = const [],
  List<Payment> payments = const [],
  List<JobPhoto> photos = const [],
  bool isSynced = true,
}) => JobDetails(
  job: job ?? testJob(),
  customer: customer ?? testCustomer(),
  items: items,
  payments: payments,
  photos: photos,
  isSynced: isSynced,
);
