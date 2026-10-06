import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/async/single_flight.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';

part 'request_state.dart';

/// One of the consumer's requests, from sending to rating.
///
/// Offers, the technician's progress and price changes arrive from the
/// server, so the request is fetched again every `pollEvery` while it is
/// in progress. Every action fetches it again when done.
class RequestCubit extends Cubit<RequestState> {
  RequestCubit({
    required this._requests,
    required this._requestId,
    this._pollEvery = const Duration(seconds: 20),
  }) : super(const RequestState());

  final ConsumerRequestsRepository _requests;
  final String _requestId;
  final Duration _pollEvery;
  Timer? _poll;
  late final _fetch = SingleFlight(_fetchRequest);

  /// Fetches the request and keeps it fresh until the cubit closes.
  Future<void> start() async {
    _poll ??= Timer.periodic(_pollEvery, (_) {
      if (state.details?.stage.isActive ?? false) unawaited(refresh());
    });
    await refresh();
  }

  /// Fetches the request again. A failed refresh keeps the request shown.
  Future<void> refresh() => _fetch();

  Future<void> _fetchRequest() async {
    final result = await _requests.fetchRequest(_requestId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final details?):
        emit(
          state.copyWith(status: RequestLoadStatus.ready, details: details),
        );
      case Ok():
        emit(state.copyWith(status: RequestLoadStatus.missing));
      case Err() when state.details != null:
        break;
      case Err():
        emit(state.copyWith(status: RequestLoadStatus.failed));
    }
  }

  Future<bool> acceptOffer(String offerId) => _act(
    RequestAction.acceptOffer,
    () => _requests.acceptOffer(offerId),
  );

  Future<bool> cancel() =>
      _act(RequestAction.cancel, () => _requests.cancelRequest(_requestId));

  /// Lets technicians come any time that day.
  Future<bool> widenWindow() => _act(
    RequestAction.widenWindow,
    () => _requests.widenRequestWindow(_requestId),
  );

  /// Answers the price change on screen.
  Future<bool> answerPriceChange({required bool approve}) async {
    final sentAt = state.details?.job?.quoteSentAt;
    if (sentAt == null || !state.details!.hasPendingPriceChange) return false;
    return _act(
      approve ? RequestAction.approvePrice : RequestAction.declinePrice,
      () => _requests.answerPriceChange(
        _requestId,
        quoteSentAt: sentAt,
        approve: approve,
      ),
    );
  }

  Future<bool> submitReview(ReviewDraft review) => _act(
    RequestAction.review,
    () => _requests.submitReview(_requestId, review),
  );

  /// Runs one action at a time, then fetches the request again either way
  /// (a refused action usually means the request changed meanwhile) and
  /// only then ends it, so the screen never offers the same action twice.
  Future<bool> _act(
    RequestAction action,
    Future<Result<void>> Function() call,
  ) async {
    if (state.busy != null) return false;
    emit(state.copyWith(busy: () => action, failure: () => null));
    final result = await call();
    if (isClosed) return false;
    await refresh();
    if (isClosed) return false;
    final failure = switch (result) {
      Ok() => null,
      Err(:final failure) => failure,
    };
    emit(state.copyWith(busy: () => null, failure: () => failure));
    return failure == null;
  }

  @override
  Future<void> close() {
    _poll?.cancel();
    return super.close();
  }
}
