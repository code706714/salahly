import 'package:salahly/core/error/failure.dart';

/// The picked file isn't a JPEG, PNG or WebP image.
final class UnsupportedPhotoFailure extends Failure {
  const UnsupportedPhotoFailure();
}

/// The user uploaded too many photos today; the server takes more tomorrow.
final class UploadLimitFailure extends Failure {
  const UploadLimitFailure();
}
