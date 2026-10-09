import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/marketplace/data/models/marketplace_models.dart';
import 'package:salahly/features/marketplace/data/repositories/marketplace_errors.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/job_request_link.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_offering.dart';
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
  Future<Result<List<IncomingRequest>>> browseOpenRequests({
    String? categoryId,
    int limit = openRequestsPageSize,
    int offset = 0,
  }) => _call(() async {
    final json = await _client.rpc<List<dynamic>>(
      'browse_open_requests',
      params: {
        'p_category_id': categoryId,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
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
  Future<Result<void>> reviseOffer(String offerId, int pricePiastres) => _call(
    () => _client.rpc<void>(
      'revise_offer',
      params: {'p_offer_id': offerId, 'p_price_piastres': pricePiastres},
    ),
  );

  @override
  Future<Result<void>> acceptCounter(String offerId) => _call(
    () => _client.rpc<void>('accept_counter', params: {'p_offer_id': offerId}),
  );

  @override
  Future<Result<void>> withdrawOffer(String offerId) => _call(
    () => _client.rpc<void>('withdraw_offer', params: {'p_offer_id': offerId}),
  );

  @override
  Future<Result<OfferThread?>> fetchOfferThread(String offerId) =>
      _call(() async {
        final json = await _client.rpc<Map<String, dynamic>?>(
          'offer_thread',
          params: {'p_offer_id': offerId},
        );
        return json == null ? null : MarketplaceModels.offerThread(json);
      });

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
  Future<Result<TechnicianOffering>> fetchOffering() => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>>(
      'my_technician_offering',
    );
    return MarketplaceModels.offering(json);
  });

  @override
  Future<Result<int>> updateOffering(TechnicianOffering offering) =>
      _call(() async {
        final handedOver = await _client.rpc<int>(
          'update_technician_offering',
          params: {
            'p_services': [
              for (final service in offering.services)
                {
                  'service_id': service.serviceId,
                  'starting_price_piastres': service.startingPricePiastres,
                },
            ],
            'p_area_ids': offering.areaIds.toList()..sort(),
            'p_work_days': offering.workDays.toList()..sort(),
            'p_service_radius_km': offering.radiusKm,
          },
        );
        return handedOver;
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
