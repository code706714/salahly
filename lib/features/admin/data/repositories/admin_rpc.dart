import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Calls the `admin_*` functions with the admin's own session and turns
/// what goes wrong into failures. The server refuses anyone who is not an
/// admin; nothing here decides that.
class AdminRpc {
  AdminRpc(this._client);

  final SupabaseClient _client;

  /// Calls [function] and reads its JSON object with [parse].
  ///
  /// Null values in [params] are sent as null, which some functions treat
  /// differently from leaving the argument out.
  Future<Result<T>> call<T>(
    String function,
    Map<String, Object?> params,
    T Function(Map<String, dynamic> json) parse,
  ) async {
    try {
      final json = await _client.rpc<Map<String, dynamic>>(
        function,
        params: params,
      );
      return Ok(parse(json));
    } on Object catch (error) {
      return Err(adminFailureFrom(error));
    }
  }

  /// Calls [function] for what it changes, not for what it returns.
  Future<Result<void>> run(String function, Map<String, Object?> params) =>
      call<void>(function, params, (_) {});
}

/// The failure for an error an admin function raises by name, or the common
/// one for anything else.
Failure adminFailureFrom(Object error) {
  if (error is PostgrestException) {
    switch (error.message) {
      case 'admin_required':
        return const AdminRequiredFailure();
      case 'recent_login_required':
        return const RecentLoginRequiredFailure();
      case 'not_pending':
        return const NotPendingFailure();
      case 'verification_not_found' ||
          'topup_not_found' ||
          'complaint_not_found' ||
          'user_not_found' ||
          'pack_not_found' ||
          'account_not_found' ||
          'area_not_found':
        return const AdminNotFoundFailure();
      case 'invalid_reason' ||
          'invalid_value' ||
          'invalid_filter' ||
          'invalid_search' ||
          'invalid_period' ||
          'invalid_target' ||
          'nothing_to_update':
        return const InvalidInputFailure();
      case 'duplicate_pack' || 'duplicate_area':
        return const DuplicateFailure();
      case 'last_active_pack' || 'last_active_account':
        return const LastActiveFailure();
      case 'cannot_suspend_admin':
        return const CannotSuspendAdminFailure();
    }
  }
  return commonFailureFrom(error);
}
