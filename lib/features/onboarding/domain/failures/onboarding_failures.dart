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
