import 'package:equatable/equatable.dart';

/// The request behind a job the platform sent the technician, and whether
/// the consumer was already told he is almost there.
final class JobRequestLink extends Equatable {
  const JobRequestLink({required this.requestId, this.arrivingSentAt});

  final String requestId;

  /// When the consumer was last told; null if never.
  final DateTime? arrivingSentAt;

  @override
  List<Object?> get props => [requestId, arrivingSentAt];
}
