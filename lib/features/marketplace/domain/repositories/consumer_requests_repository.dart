import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/request_draft.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';

/// The consumer's side of the marketplace. Every call needs the network;
/// failures name what went wrong (see marketplace_failures.dart).
abstract interface class ConsumerRequestsRepository {
  /// The address book, oldest first.
  Future<Result<List<ConsumerAddress>>> fetchAddresses();

  /// Adds an address, or updates the one with [id]. Returns its id.
  Future<Result<String>> saveAddress(ConsumerAddressDraft draft, {String? id});

  Future<Result<void>> deleteAddress(String id);

  /// Verified technicians who cover [areaId] and offer [categoryId].
  Future<Result<int>> availableTechnicianCount({
    required String categoryId,
    required String areaId,
  });

  /// Uploads a cleaned photo for a request or complaint. Returns its path.
  Future<Result<String>> uploadPhoto(String localPath);

  /// Sends a request, holding one of the consumer's uses.
  Future<Result<SentRequest>> sendRequest(RequestDraft draft);

  /// The consumer's requests, newest first.
  Future<Result<List<RequestSummary>>> fetchRequests();

  /// One request with its offers and progress, or null if it isn't theirs.
  Future<Result<RequestDetails?>> fetchRequest(String id);

  /// A technician's page, or null unless they made the consumer an offer.
  Future<Result<TechnicianPublicProfile?>> fetchTechnician(String id);

  /// Picks an offer; the technician gets the job.
  Future<Result<void>> acceptOffer(String offerId);

  Future<Result<void>> cancelRequest(String id);

  /// Lets technicians come any time that day.
  Future<Result<void>> widenRequestWindow(String id);

  /// Accepts or declines the price change sent at [quoteSentAt].
  Future<Result<void>> answerPriceChange(
    String requestId, {
    required DateTime quoteSentAt,
    required bool approve,
  });

  Future<Result<void>> submitReview(String requestId, ReviewDraft review);

  Future<Result<void>> submitComplaint(
    String requestId,
    ComplaintDraft complaint,
  );

  /// A short-lived link to show one of the consumer's request photos.
  Future<Result<String>> photoUrl(String path);
}
