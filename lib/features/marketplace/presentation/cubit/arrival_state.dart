part of 'arrival_cubit.dart';

final class ArrivalState extends Equatable {
  const ArrivalState({
    this.requestId,
    this.sentAt,
    this.isSending = false,
    this.failure,
  });

  /// The request behind the job, once known.
  final String? requestId;

  /// When the consumer was told; null until then.
  final DateTime? sentAt;
  final bool isSending;

  /// Why the last try failed.
  final Failure? failure;

  bool get isSent => sentAt != null;

  ArrivalState copyWith({
    String? requestId,
    DateTime? sentAt,
    bool? isSending,
    Failure? Function()? failure,
  }) => ArrivalState(
    requestId: requestId ?? this.requestId,
    sentAt: sentAt ?? this.sentAt,
    isSending: isSending ?? this.isSending,
    failure: failure == null ? this.failure : failure(),
  );

  @override
  List<Object?> get props => [requestId, sentAt, isSending, failure];
}
