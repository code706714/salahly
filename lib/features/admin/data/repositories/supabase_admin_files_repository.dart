import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminFilesRepository implements AdminFilesRepository {
  SupabaseAdminFilesRepository(this._client);

  final SupabaseClient _client;

  /// How long a link works, in seconds. The page shows the file right away,
  /// so a minute is plenty.
  static const linkLifetime = 60;

  @override
  Future<Result<String>> signedUrl(AdminBucket bucket, String path) async {
    try {
      return Ok(
        await _client.storage
            .from(bucket.id)
            .createSignedUrl(path, linkLifetime),
      );
    } on Object catch (error) {
      return Err(commonFailureFrom(error));
    }
  }
}
