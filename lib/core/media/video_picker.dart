import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/core/media/photo_picker.dart';

/// Picks a short video of a fault for a request.
///
/// The storage bucket takes only MP4 and MOV files of up to [maxBytes], so
/// anything else is turned away here, before the upload. The video is kept
/// as recorded: unlike photos, its metadata is not stripped.
class VideoPicker {
  VideoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// The longest clip the camera records.
  static const maxDuration = Duration(seconds: 30);

  /// The largest file the bucket takes.
  static const int maxBytes = 15 * 1024 * 1024;

  static const Set<String> _extensions = {'mp4', 'mov'};

  /// The video's path, null if the user cancelled, or why it was refused.
  Future<Result<String?>> pick({required PhotoSource source}) async {
    final picked = await _picker.pickVideo(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      maxDuration: maxDuration,
    );
    if (picked == null) return const Ok(null);
    final extension = picked.path.split('.').last.toLowerCase();
    final file = File(picked.path);
    if (!_extensions.contains(extension) || await file.length() > maxBytes) {
      await discard(picked.path);
      return const Err(VideoRejectedFailure());
    }
    return Ok(picked.path);
  }

  /// Deletes a video this picker returned once it is not needed anymore.
  Future<void> discard(String path) async {
    try {
      await File(path).delete();
    } on FileSystemException {
      // Left for the system to clear with the rest of the cache.
    }
  }
}
