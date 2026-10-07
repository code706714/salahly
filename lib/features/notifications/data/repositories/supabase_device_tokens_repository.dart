import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';
import 'package:salahly/features/notifications/domain/repositories/device_tokens_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDeviceTokensRepository implements DeviceTokensRepository {
  SupabaseDeviceTokensRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<void>> register(String token, DevicePlatform platform) => _call(
    () => _client.rpc<void>(
      'register_device_token',
      params: {'p_token': token, 'p_platform': platform.name},
    ),
  );

  @override
  Future<Result<void>> unregister(String token) => _call(
    () => _client.rpc<void>(
      'unregister_device_token',
      params: {'p_token': token},
    ),
  );

  static Future<Result<void>> _call(Future<void> Function() action) async {
    try {
      await action();
      return const Ok(null);
    } on Object catch (error) {
      return Err(commonFailureFrom(error));
    }
  }
}
