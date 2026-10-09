import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';

part 'offer_thread_state.dart';

/// The price talk of one offer, for whoever of the two is reading it.
class OfferThreadCubit extends Cubit<OfferThreadState> {
  OfferThreadCubit({required this._fetch}) : super(const OfferThreadState());

  /// Reads the thread from the consumer's or the technician's repository.
  final Future<Result<OfferThread?>> Function() _fetch;

  /// Fetches the thread; again after a failure.
  Future<void> load() async {
    if (state.status == OfferThreadStatus.failed) {
      emit(const OfferThreadState());
    }
    final result = await _fetch();
    if (isClosed) return;
    emit(switch (result) {
      Ok(value: final thread?) => OfferThreadState(
        status: OfferThreadStatus.ready,
        thread: thread,
      ),
      Ok() => const OfferThreadState(status: OfferThreadStatus.missing),
      Err(:final failure) => OfferThreadState(
        status: OfferThreadStatus.failed,
        failure: failure,
      ),
    });
  }
}
