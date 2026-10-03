import 'dart:io';

import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Uploads a photo the `PhotoPicker` cleaned into the signed-in user's own
/// folder of a storage bucket, `<user id>/<random uuid>.<ext>`: the only
/// place the storage policies accept it.
class PhotoUploader {
  PhotoUploader(this._client, {this._uuid = const Uuid()});

  final SupabaseClient _client;
  final Uuid _uuid;

  static const _contentTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  /// The stored path.
  Future<Result<String>> upload(
    String localPath, {
    required String bucket,
  }) async {
    final extension = localPath.split('.').last.toLowerCase();
    final contentType = _contentTypes[extension];
    if (contentType == null) return const Err(UnsupportedPhotoFailure());
    try {
      final userId = _client.auth.currentUser!.id;
      final normalized = extension == 'jpeg' ? 'jpg' : extension;
      final path = '$userId/${_uuid.v4()}.$normalized';
      await _client.storage
          .from(bucket)
          .upload(
            path,
            File(localPath),
            fileOptions: FileOptions(contentType: contentType),
          );
      return Ok(path);
    } on StorageException catch (error) {
      // The storage policy refuses uploads past the daily limit.
      if (error.statusCode == '403') return const Err(UploadLimitFailure());
      return Err(commonFailureFrom(error));
    } on Object catch (error) {
      return Err(commonFailureFrom(error));
    }
  }
}
