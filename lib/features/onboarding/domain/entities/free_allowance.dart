import 'package:equatable/equatable.dart';

/// How many free uses new users get, as configured by the platform team.
final class FreeAllowance extends Equatable {
  const FreeAllowance({
    required this.consumerRequests,
    required this.technicianJobs,
  });

  final int consumerRequests;
  final int technicianJobs;

  @override
  List<Object?> get props => [consumerRequests, technicianJobs];
}
