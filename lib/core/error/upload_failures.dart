import 'package:salahly/core/error/failure.dart';

/// The picked file isn't a JPEG, PNG or WebP image.
final class UnsupportedPhotoFailure extends Failure {
  const UnsupportedPhotoFailure();
}

/// The picked video isn't an MP4 or MOV, or is too large to upload.
final class VideoRejectedFailure extends Failure {
  const VideoRejectedFailure();
}

/// The user uploaded too many photos today; the server takes more tomorrow.
final class UploadLimitFailure extends Failure {
  const UploadLimitFailure();
}
