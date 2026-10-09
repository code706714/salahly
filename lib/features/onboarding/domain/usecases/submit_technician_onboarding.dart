import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/onboarding/domain/entities/technician_onboarding.dart';
import 'package:salahly/features/onboarding/domain/failures/onboarding_failures.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';

/// Uploads the four photos, then saves the profile in one call.
///
/// Keep one instance per onboarding attempt: photos that uploaded before a
/// failure are remembered, so a retry only sends what is missing.
class SubmitTechnicianOnboarding {
  SubmitTechnicianOnboarding(this._repository);

  final OnboardingRepository _repository;
  final _uploaded = <String, String>{};

  Future<Result<void>> call(TechnicianOnboarding input) async {
    final local = input.photos;
    final uploads = <(String, PhotoKind)>[
      (local.avatar, PhotoKind.avatar),
      (local.idFront, PhotoKind.idDocument),
      (local.idBack, PhotoKind.idDocument),
      (local.selfieWithId, PhotoKind.idDocument),
    ];
    for (final (path, kind) in uploads) {
      if (_uploaded.containsKey(path)) continue;
      final result = await _repository.uploadPhoto(path, kind);
      switch (result) {
        case Ok(:final value):
          _uploaded[path] = value;
        case Err(:final failure):
          return Err(failure);
      }
    }

    final result = await _repository.completeTechnicianOnboarding(
      TechnicianOnboarding(
        fullName: input.fullName,
        shopName: input.shopName,
        yearsExperience: input.yearsExperience,
        baseAreaId: input.baseAreaId,
        baseLocation: input.baseLocation,
        serviceRadiusKm: input.serviceRadiusKm,
        workDays: input.workDays,
        areaIds: input.areaIds,
        startingPricesPiastres: input.startingPricesPiastres,
        photos: TechnicianDocuments(
          avatar: _uploaded[local.avatar]!,
          idFront: _uploaded[local.idFront]!,
          idBack: _uploaded[local.idBack]!,
          selfieWithId: _uploaded[local.selfieWithId]!,
        ),
      ),
    );
    return switch (result) {
      Err(failure: AlreadyOnboardedFailure()) => const Ok(null),
      Err(failure: InvalidPhotosFailure()) => _forgetUploads(result),
      _ => result,
    };
  }

  Result<void> _forgetUploads(Result<void> result) {
    _uploaded.clear();
    return result;
  }
}
