part of 'offer_thread_cubit.dart';

enum OfferThreadStatus { loading, ready, missing, failed }

final class OfferThreadState extends Equatable {
  const OfferThreadState({
    this.status = OfferThreadStatus.loading,
    this.thread,
    this.failure,
  });

  final OfferThreadStatus status;
  final OfferThread? thread;

  /// Why the thread couldn't be fetched.
  final Failure? failure;

  @override
  List<Object?> get props => [status, thread, failure];
}
