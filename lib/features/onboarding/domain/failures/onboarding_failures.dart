import 'package:salahly/core/error/failure.dart';

/// The server already has this side's profile, e.g. a retry after a
/// response was lost. Callers treat it as success.
final class AlreadyOnboardedFailure extends Failure {
  const AlreadyOnboardedFailure();
}

/// The uploaded photos were rejected and must be taken again.
final class InvalidPhotosFailure extends Failure {
  const InvalidPhotosFailure();
}

/// The picked file isn't a JPEG, PNG or WebP image.
final class UnsupportedPhotoFailure extends Failure {
  const UnsupportedPhotoFailure();
}

/// The user uploaded too many photos today; the server takes more tomorrow.
final class UploadLimitFailure extends Failure {
  const UploadLimitFailure();
}
