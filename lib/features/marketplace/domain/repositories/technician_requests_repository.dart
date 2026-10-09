import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_offering.dart';

/// Requests fetched per page of the open requests.
const openRequestsPageSize = 20;

/// The technician's side of the marketplace: requests sent to them and
/// their offers. Every call needs the network.
abstract interface class TechnicianRequestsRepository {
  /// Open requests waiting for this technician's offer, newest first.
  Future<Result<List<IncomingRequest>>> fetchNewRequests();

  /// Every open request in this technician's trades and areas, newest
  /// first, whether or not it was sent to them. [offset] pages through them.
  Future<Result<List<IncomingRequest>>> browseOpenRequests({
    String? categoryId,
    int limit = openRequestsPageSize,
    int offset = 0,
  });

  /// One request sent to this technician, marking it seen; null if it
  /// wasn't sent to them.
  Future<Result<IncomingRequest?>> fetchRequest(String id);

  /// Sends an offer. Returns its id.
  Future<Result<String>> sendOffer(String requestId, OfferDraft offer);

  /// Lowers the price of the offer to [pricePiastres].
  Future<Result<void>> reviseOffer(String offerId, int pricePiastres);

  /// Takes the consumer's price: the consumer's pick goes through.
  Future<Result<void>> acceptCounter(String offerId);

  /// Takes the offer back before it is picked.
  Future<Result<void>> withdrawOffer(String offerId);

  /// The price talk of an offer, or null if it isn't theirs.
  Future<Result<OfferThread?>> fetchOfferThread(String offerId);

  /// "مش مناسب ليا": the request leaves their new requests.
  Future<Result<void>> dismissRequest(String requestId);

  /// The services this technician offers, with their starting prices: the
  /// price chips on an offer.
  Future<Result<List<ServicePrice>>> fetchMyServices();

  /// What this technician offers.
  Future<Result<TechnicianOffering>> fetchOffering();

  /// Replaces what this technician offers; the open requests that now match
  /// are handed to them. Returns how many.
  Future<Result<int>> updateOffering(TechnicianOffering offering);

  /// The request behind the platform job [jobId], or null if it isn't this
  /// technician's.
  Future<Result<JobRequestLink?>> fetchJobRequest(String jobId);

  /// Tells the consumer of [requestId] the technician is almost there. Asking
  /// again soon sends nothing more. Returns when the consumer was told.
  Future<Result<DateTime>> sendArriving(String requestId);

  /// A short-lived link to show one of a request's photos.
  Future<Result<String>> photoUrl(String path);
}
