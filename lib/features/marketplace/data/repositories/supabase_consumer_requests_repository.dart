import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/media/photo_uploader.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/marketplace/data/models/marketplace_models.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:salahly/features/marketplace/data/repositories/marketplace_errors.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/request_draft.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConsumerRequestsRepository implements ConsumerRequestsRepository {
  SupabaseConsumerRequestsRepository(this._client)
    : _photos = PhotoUploader(_client);

  final SupabaseClient _client;
  final PhotoUploader _photos;

  static const _photoBucket = 'request-photos';

  @override
  Future<Result<List<ConsumerAddress>>> fetchAddresses() => _call(() async {
    final rows = await _client
        .from('consumer_addresses')
        .select(MarketplaceModels.addressSelect)
        .order('created_at');
    return rows.map(MarketplaceModels.address).toList();
  });

  @override
  Future<Result<String>> saveAddress(
    ConsumerAddressDraft draft, {
    String? id,
  }) => _call(
    () => _client.rpc<String>(
      'save_consumer_address',
      params: {
        'p_id': id,
        'p_label': draft.label,
        'p_area_id': draft.areaId,
        'p_details': draft.details,
      },
    ),
  );

  @override
  Future<Result<void>> deleteAddress(String id) => _call(
    () => _client.rpc<void>('delete_consumer_address', params: {'p_id': id}),
  );

  @override
  Future<Result<int>> availableTechnicianCount({
    required String categoryId,
    required String areaId,
  }) => _call(
    () => _client.rpc<int>(
      'available_technician_count',
      params: {'p_category_id': categoryId, 'p_area_id': areaId},
    ),
  );

  @override
  Future<Result<String>> uploadPhoto(String localPath) =>
      _photos.upload(localPath, bucket: _photoBucket);

  @override
  Future<Result<SentRequest>> sendRequest(RequestDraft draft) =>
      _call(() async {
        final json = await _client.rpc<Map<String, dynamic>>(
          'create_service_request',
          params: {
            'p_category_id': draft.categoryId,
            'p_issue': toWire(draft.issue),
            'p_description': draft.description,
            'p_photo_paths': draft.photoPaths,
            'p_address_id': draft.addressId,
            'p_preferred_on': CalendarDate.format(draft.day),
            'p_window': toWire(draft.window),
            'p_technician_id': draft.technicianId,
          },
        );
        return SentRequest(
          id: json['id'] as String,
          sentTo: json['sent_to'] as int,
        );
      });

  @override
  Future<Result<List<RequestSummary>>> fetchRequests() => _call(() async {
    final json = await _client.rpc<List<dynamic>>('my_requests');
    return listFromWire(json).map(MarketplaceModels.summary).toList();
  });

  @override
  Future<Result<RequestDetails?>> fetchRequest(String id) => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>?>(
      'request_details',
      params: {'p_request_id': id},
    );
    return json == null ? null : MarketplaceModels.details(json);
  });

  @override
  Future<Result<TechnicianPublicProfile?>> fetchTechnician(String id) =>
      _call(() async {
        final json = await _client.rpc<Map<String, dynamic>?>(
          'technician_profile',
          params: {'p_technician_id': id},
        );
        return json == null ? null : MarketplaceModels.technicianProfile(json);
      });

  @override
  Future<Result<void>> acceptOffer(String offerId) => _call(
    () => _client.rpc<void>('accept_offer', params: {'p_offer_id': offerId}),
  );

  @override
  Future<Result<void>> cancelRequest(String id) => _call(
    () => _client.rpc<void>(
      'cancel_service_request',
      params: {'p_request_id': id},
    ),
  );

  @override
  Future<Result<void>> widenRequestWindow(String id) => _call(
    () => _client.rpc<void>(
      'widen_request_window',
      params: {'p_request_id': id},
    ),
  );

  @override
  Future<Result<void>> answerPriceChange(
    String requestId, {
    required DateTime quoteSentAt,
    required bool approve,
  }) => _call(
    () => _client.rpc<void>(
      'answer_price_change',
      params: {
        'p_request_id': requestId,
        'p_quote_sent_at': quoteSentAt.toUtc().toIso8601String(),
        'p_approve': approve,
      },
    ),
  );

  @override
  Future<Result<void>> submitReview(String requestId, ReviewDraft review) =>
      _call(
        () => _client.rpc<void>(
          'submit_review',
          params: {
            'p_request_id': requestId,
            'p_stars': review.stars,
            'p_tags': [for (final tag in review.tags) toWire(tag)],
            'p_comment': review.comment,
            'p_paid_with': toWire(review.paidWith),
          },
        ),
      );

  @override
  Future<Result<void>> submitComplaint(
    String requestId,
    ComplaintDraft complaint,
  ) => _call(
    () => _client.rpc<void>(
      'submit_complaint',
      params: {
        'p_request_id': requestId,
        'p_reason': toWire(complaint.reason),
        'p_details': complaint.details,
        'p_photo_path': complaint.photoPath,
      },
    ),
  );

  @override
  Future<Result<String>> photoUrl(String path) => _call(
    () => _client.storage
        .from(_photoBucket)
        .createSignedUrl(path, photoLinkSeconds),
  );

  static Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on Object catch (error) {
      return Err<T>(_failureFrom(error));
    }
  }

  static Failure _failureFrom(Object error) =>
      marketplaceFailureFrom(error) ?? commonFailureFrom(error);
}
