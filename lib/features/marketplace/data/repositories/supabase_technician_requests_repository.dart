import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/features/marketplace/data/models/marketplace_models.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:salahly/features/marketplace/data/repositories/marketplace_errors.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseTechnicianRequestsRepository
    implements TechnicianRequestsRepository {
  SupabaseTechnicianRequestsRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<List<IncomingRequest>>> fetchNewRequests() => _call(() async {
    final json = await _client.rpc<List<dynamic>>('technician_requests');
    return listFromWire(json).map(MarketplaceModels.incoming).toList();
  });

  @override
  Future<Result<IncomingRequest?>> fetchRequest(String id) => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>?>(
      'technician_request',
      params: {'p_request_id': id},
    );
    return json == null ? null : MarketplaceModels.incoming(json);
  });

  @override
  Future<Result<String>> sendOffer(String requestId, OfferDraft offer) => _call(
    () => _client.rpc<String>(
      'send_offer',
      params: {
        'p_request_id': requestId,
        'p_service_id': offer.serviceId,
        'p_price_piastres': offer.pricePiastres,
        'p_arrive_at': offer.arriveAt.toUtc().toIso8601String(),
        'p_note': offer.note,
      },
    ),
  );

  @override
  Future<Result<void>> dismissRequest(String requestId) => _call(
    () => _client.rpc<void>(
      'dismiss_request',
      params: {'p_request_id': requestId},
    ),
  );

  @override
  Future<Result<List<ServicePrice>>> fetchMyServices() => _call(() async {
    final rows = await _client
        .from('technician_services')
        .select('service_id, starting_price_piastres')
        .order('service_id', ascending: true);
    return [
      for (final row in rows)
        ServicePrice(
          serviceId: row['service_id'] as String,
          startingPricePiastres: row['starting_price_piastres'] as int,
        ),
    ];
  });

  @override
  Future<Result<JobRequestLink?>> fetchJobRequest(String jobId) =>
      _call(() async {
        final json = await _client.rpc<Map<String, dynamic>?>(
          'platform_job_request',
          params: {'p_job_id': jobId},
        );
        return json == null ? null : MarketplaceModels.jobRequestLink(json);
      });

  @override
  Future<Result<DateTime>> sendArriving(String requestId) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
        'technician_arriving',
        params: {'p_request_id': requestId},
      );
      return Ok(timeFromWire(json['sent_at']));
    } on PostgrestException catch (error) {
      // The same code the address book uses for its own limit.
      if (error.message == 'limit_reached') {
        return const Err(ArrivalLimitFailure());
      }
      return Err(_failureFrom(error));
    } on Object catch (error) {
      return Err(_failureFrom(error));
    }
  }

  @override
  Future<Result<String>> photoUrl(String path) => _call(
    () => _client.storage
        .from('request-photos')
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
