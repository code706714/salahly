import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';

/// The technician's side of the marketplace: requests sent to them and
/// their offers. Every call needs the network.
abstract interface class TechnicianRequestsRepository {
  /// Open requests waiting for this technician's offer, newest first.
  Future<Result<List<IncomingRequest>>> fetchNewRequests();

  /// One request sent to this technician, marking it seen; null if it
  /// wasn't sent to them.
  Future<Result<IncomingRequest?>> fetchRequest(String id);

  /// Sends an offer. Returns its id.
  Future<Result<String>> sendOffer(String requestId, OfferDraft offer);

  /// "مش مناسب ليا": the request leaves their new requests.
  Future<Result<void>> dismissRequest(String requestId);

  /// The services this technician offers, with their starting prices: the
  /// price chips on an offer.
  Future<Result<List<ServicePrice>>> fetchMyServices();

  /// The request behind the platform job [jobId], or null if it isn't this
  /// technician's.
  Future<Result<JobRequestLink?>> fetchJobRequest(String jobId);

  /// Tells the consumer of [requestId] the technician is almost there. Asking
  /// again soon sends nothing more. Returns when the consumer was told.
  Future<Result<DateTime>> sendArriving(String requestId);

  /// A short-lived link to show one of a request's photos.
  Future<Result<String>> photoUrl(String path);
}
