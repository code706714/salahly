import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/onboarding/domain/entities/consumer_onboarding.dart';
import 'package:salahly/features/onboarding/domain/entities/free_allowance.dart';
import 'package:salahly/features/onboarding/domain/entities/technician_onboarding.dart';

enum PhotoKind {
  /// Shown to customers.
  avatar,

  /// Seen by the verification team only.
  idDocument,
}

abstract interface class OnboardingRepository {
  Future<Result<FreeAllowance>> fetchFreeAllowance();

  Future<Result<void>> completeConsumerOnboarding(ConsumerOnboarding input);

  /// Uploads the photo at [localPath] and returns its storage path.
  Future<Result<String>> uploadPhoto(String localPath, PhotoKind kind);

  /// Saves the technician profile. The photos in [input] must be storage
  /// paths returned by [uploadPhoto].
  Future<Result<void>> completeTechnicianOnboarding(TechnicianOnboarding input);
}
