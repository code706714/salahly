import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';

abstract interface class AccountRepository {
  /// The profile last fetched on this device for [userId], so the app can
  /// open offline.
  Future<UserProfile?> cachedProfile(String userId);

  /// Fetches the profile and caches it. `Ok(null)` means the user hasn't
  /// finished onboarding yet.
  Future<Result<UserProfile?>> fetchProfile(String userId);

  /// Deletes the signed-in person's account for good, after cancelling
  /// what is open. Fails with `PendingTransferFailure` while a transfer
  /// waits to be checked, and with `RecentLoginRequiredFailure` when the
  /// person last signed in more than 15 minutes ago.
  Future<Result<void>> deleteAccount();

  /// Forgets everything cached for the signed-out user.
  Future<void> clearCache();
}
