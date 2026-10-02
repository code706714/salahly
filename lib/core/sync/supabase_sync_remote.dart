import 'dart:io';

import 'package:salahly/core/sync/sync_remote.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSyncRemote implements SyncRemote {
  const SupabaseSyncRemote(this._client);

  static const photoBucket = 'job-photos';

  final SupabaseClient _client;

  @override
  Future<List<SyncRejection>> push(List<SyncChange> changes) async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'sync_push',
      params: {
        'p_changes': [for (final change in changes) change.toJson()],
      },
    );
    return [
      for (final rejection in result['rejected'] as List<dynamic>)
        SyncRejection.fromJson(rejection as Map<String, dynamic>),
    ];
  }

  @override
  Future<PullPage> pull(Map<String, dynamic>? checkpoint) async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'sync_pull',
      params: {'p_checkpoint': checkpoint},
    );
    return PullPage.fromJson(result);
  }

  @override
  Future<void> uploadPhoto({
    required String storagePath,
    required String localPath,
  }) async {
    try {
      await _client.storage
          .from(photoBucket)
          .upload(
            storagePath,
            File(localPath),
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    } on StorageException catch (error) {
      switch (error.statusCode) {
        // Already uploaded by an earlier attempt whose reply was lost.
        case '409':
          return;
        case '403':
          throw const UploadRefusedException();
        default:
          rethrow;
      }
    }
  }
}
