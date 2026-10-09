import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/async/single_flight.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';

part 'offer_state.dart';

/// One request sent to the technician, and their answer to it: an offer,
/// or "مش مناسب ليا".
///
/// Every action fetches the request again when done, so the screen shows
/// the offer as sent, or why the request no longer takes one.
class OfferCubit extends Cubit<OfferState> {
  OfferCubit({
    required this._requests,
    required this._requestId,
    this._clock = DateTime.now,
  }) : super(OfferState(now: _clock()));

  final TechnicianRequestsRepository _requests;
  final String _requestId;
  final DateTime Function() _clock;
  late final _fetch = SingleFlight(_fetchRequest);

  /// Fetches the request and the technician's services.
  Future<void> start() async {
    await Future.wait([fetchRequest(), fetchMyServices()]);
  }

  /// Fetches the request, marking it seen. A failed refresh keeps the
  /// request shown.
  Future<void> fetchRequest() => _fetch();

  Future<void> _fetchRequest() async {
    final result = await _requests.fetchRequest(_requestId);
    if (isClosed) return;
    switch (result) {
      case Ok(value: final request?):
        emit(
          state.copyWith(
            status: OfferLoadStatus.ready,
            request: request,
            now: _clock(),
          ),
        );
        await _fetchPhotoUrls(request);
      case Ok():
        emit(state.copyWith(status: OfferLoadStatus.missing));
      case Err() when state.request != null:
        break;
      case Err():
        emit(state.copyWith(status: OfferLoadStatus.failed));
    }
  }

  /// Links for the request's photos not linked yet; a photo whose link
  /// fails shows as a placeholder.
  Future<void> _fetchPhotoUrls(IncomingRequest request) async {
    final paths = request.photoPaths.where(
      (path) => !state.photoUrls.containsKey(path),
    );
    final links = await Future.wait([
      for (final path in paths)
        _requests.photoUrl(path).then((result) => (path, result)),
    ]);
    if (isClosed || links.isEmpty) return;
    emit(
      state.copyWith(
        photoUrls: {
          ...state.photoUrls,
          for (final (path, result) in links)
            if (result case Ok(:final value)) path: value,
        },
      ),
    );
  }

  /// The technician's services with their starting prices, for the price
  /// chips. Without them the price is typed.
  Future<void> fetchMyServices() async {
    final result = await _requests.fetchMyServices();
    if (isClosed) return;
    if (result case Ok(:final value)) emit(state.copyWith(services: value));
  }

  /// Sends [offer], if the request still takes one.
  Future<bool> sendOffer(OfferDraft offer) async {
    if (!(state.request?.acceptsOffers ?? false)) return false;
    return _act(OfferAction.send, () async {
      final result = await _requests.sendOffer(_requestId, offer);
      return switch (result) {
        Ok() => const Ok(null),
        Err(:final failure) => Err(failure),
      };
    });
  }

  /// Lowers the price of the offer sent, if it can still be lowered.
  Future<bool> reviseOffer(int pricePiastres) {
    final offer = state.request?.myOffer;
    if (offer == null) return Future.value(false);
    return _act(
      OfferAction.revise,
      () => _requests.reviseOffer(offer.id, pricePiastres),
    );
  }

  /// Takes the consumer's price, which picks this technician.
  Future<bool> acceptCounter() {
    final offer = state.request?.myOffer;
    if (offer == null) return Future.value(false);
    return _act(
      OfferAction.acceptCounter,
      () => _requests.acceptCounter(offer.id),
    );
  }

  /// Takes the offer back, which can't be undone.
  Future<bool> withdrawOffer() {
    final offer = state.request?.myOffer;
    if (offer == null) return Future.value(false);
    return _act(
      OfferAction.withdraw,
      () => _requests.withdrawOffer(offer.id),
    );
  }

  /// "مش مناسب ليا": the request leaves the technician's new requests.
  Future<bool> dismissRequest() => _act(
    OfferAction.dismiss,
    () => _requests.dismissRequest(_requestId),
  );

  /// Runs one action at a time, then fetches the request again either way
  /// (a refused offer usually means the request changed meanwhile) and
  /// only then ends it, so the screen never offers the same action twice.
  Future<bool> _act(
    OfferAction action,
    Future<Result<void>> Function() call,
  ) async {
    if (state.busy != null) return false;
    emit(state.copyWith(busy: () => action, failure: () => null));
    final result = await call();
    if (isClosed) return false;
    await fetchRequest();
    if (isClosed) return false;
    final failure = switch (result) {
      Ok() => null,
      Err(:final failure) => failure,
    };
    emit(state.copyWith(busy: () => null, failure: () => failure));
    return failure == null;
  }
}
