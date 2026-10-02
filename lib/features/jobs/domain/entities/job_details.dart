import 'package:equatable/equatable.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';

/// Everything about one job, for its own screens.
final class JobDetails extends Equatable {
  const JobDetails({
    required this.job,
    required this.customer,
    required this.items,
    required this.payments,
    required this.photos,
    required this.isSynced,
  });

  final Job job;
  final Customer customer;

  /// In display order.
  final List<JobItem> items;

  /// Oldest first.
  final List<Payment> payments;
  final List<JobPhoto> photos;

  /// False while some of the job's changes are only on this phone.
  final bool isSynced;

  int get totalPiastres =>
      items.fold(0, (sum, item) => sum + item.totalPiastres);

  int get paidPiastres =>
      payments.fold(0, (sum, payment) => sum + payment.amountPiastres);

  int get balancePiastres {
    final balance = totalPiastres - paidPiastres;
    return balance > 0 ? balance : 0;
  }

  /// Where the work is: the job's own address, else the customer's.
  String? get address => job.address ?? customer.address;

  List<JobPhoto> photosOf(PhotoKind kind) =>
      photos.where((photo) => photo.kind == kind).toList();

  @override
  List<Object?> get props => [job, customer, items, payments, photos, isSynced];
}
