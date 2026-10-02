import 'package:equatable/equatable.dart';

enum PaymentMethod { cash, instapay, vodafoneCash, other }

/// Money received for a job.
final class Payment extends Equatable {
  const Payment({
    required this.id,
    required this.jobId,
    required this.amountPiastres,
    required this.method,
    required this.receivedAt,
  });

  final String id;
  final String jobId;
  final int amountPiastres;
  final PaymentMethod method;
  final DateTime receivedAt;

  @override
  List<Object?> get props => [id, jobId, amountPiastres, method, receivedAt];
}
