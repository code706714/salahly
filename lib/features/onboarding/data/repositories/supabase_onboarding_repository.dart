import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/media/photo_uploader.dart';
import 'package:salahly/features/onboarding/domain/entities/consumer_onboarding.dart';
import 'package:salahly/features/onboarding/domain/entities/free_allowance.dart';
import 'package:salahly/features/onboarding/domain/entities/technician_onboarding.dart';
import 'package:salahly/features/onboarding/domain/failures/onboarding_failures.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOnboardingRepository implements OnboardingRepository {
  SupabaseOnboardingRepository(this._client) : _photos = PhotoUploader(_client);

  final SupabaseClient _client;
  final PhotoUploader _photos;

  @override
  Future<Result<FreeAllowance>> fetchFreeAllowance() async {
    try {
      final row = await _client
          .from('app_settings')
          .select('consumer_free_requests, technician_free_jobs')
          .single();
      return Ok(
        FreeAllowance(
          consumerRequests: row['consumer_free_requests'] as int,
          technicianJobs: row['technician_free_jobs'] as int,
        ),
      );
    } on Object catch (error) {
      return Err(commonFailureFrom(error));
    }
  }

  @override
  Future<Result<void>> completeConsumerOnboarding(
    ConsumerOnboarding input,
  ) async {
    try {
      await _client.rpc<void>(
        'complete_consumer_onboarding',
        params: {
          'p_full_name': input.fullName,
          'p_honorific': input.honorific.name,
          'p_area_id': input.areaId,
        },
      );
      return const Ok(null);
    } on Object catch (error) {
      return Err(_failureFrom(error));
    }
  }

  @override
  Future<Result<String>> uploadPhoto(String localPath, PhotoKind kind) =>
      _photos.upload(
        localPath,
        bucket: switch (kind) {
          PhotoKind.avatar => 'avatars',
          PhotoKind.idDocument => 'verification-docs',
        },
      );

  @override
  Future<Result<void>> completeTechnicianOnboarding(
    TechnicianOnboarding input,
  ) async {
    try {
      await _client.rpc<void>(
        'complete_technician_onboarding',
        params: {
          'p_full_name': input.fullName,
          'p_shop_name': input.shopName,
          'p_years_experience': input.yearsExperience,
          'p_avatar_path': input.photos.avatar,
          'p_base_area_id': input.baseAreaId,
          'p_base_lat': input.baseLocation.lat,
          'p_base_lng': input.baseLocation.lng,
          'p_service_radius_km': input.serviceRadiusKm,
          'p_work_days': input.workDays.toList()..sort(),
          'p_area_ids': input.areaIds.toList(),
          'p_services': [
            for (final MapEntry(key: id, value: price)
                in input.startingPricesPiastres.entries)
              {'service_id': id, 'starting_price_piastres': price},
          ],
          'p_id_front_path': input.photos.idFront,
          'p_id_back_path': input.photos.idBack,
          'p_selfie_path': input.photos.selfieWithId,
        },
      );
      return const Ok(null);
    } on Object catch (error) {
      return Err(_failureFrom(error));
    }
  }

  static Failure _failureFrom(Object error) {
    if (error is PostgrestException) {
      switch (error.message) {
        case 'already_onboarded':
          return const AlreadyOnboardedFailure();
        case 'invalid_avatar' || 'invalid_documents':
          return const InvalidPhotosFailure();
      }
    }
    return commonFailureFrom(error);
  }
}
