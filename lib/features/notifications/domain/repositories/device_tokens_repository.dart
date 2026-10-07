import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';

/// The phones the signed-in person gets pushes on. The server keeps the
/// five most recent and never shows a token to anyone.
abstract interface class DeviceTokensRepository {
  /// Remembers this phone, or marks it as seen again.
  Future<Result<void>> register(String token, DevicePlatform platform);

  /// Forgets this phone (on sign-out).
  Future<Result<void>> unregister(String token);
}
