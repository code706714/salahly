import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

enum PhotoSource { camera, gallery }

/// How large the uploaded photo needs to be.
enum PhotoPurpose {
  avatar(shortSide: 800),
  document(shortSide: 1600),
  job(shortSide: 1280),
  request(shortSide: 1280),
  transfer(shortSide: 1600);

  const PhotoPurpose({required this.shortSide});

  /// Photos are scaled down until their shorter side is this many pixels.
  final int shortSide;
}

/// Picks a photo and re-encodes it as a JPEG without metadata.
///
/// The camera stores GPS coordinates in EXIF and the picker keeps them, so
/// every photo is stripped before it can be uploaded anywhere.
class PhotoPicker {
  PhotoPicker({ImagePicker? picker, this._uuid = const Uuid()})
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  final Uuid _uuid;

  /// The cleaned photo's path, or null if the user cancelled.
  Future<String?> pick({
    required PhotoSource source,
    required PhotoPurpose purpose,
  }) async {
    final picked = await _picker.pickImage(
      source: switch (source) {
        PhotoSource.camera => ImageSource.camera,
        PhotoSource.gallery => ImageSource.gallery,
      },
      preferredCameraDevice: purpose == PhotoPurpose.avatar
          ? CameraDevice.front
          : CameraDevice.rear,
    );
    if (picked == null) return null;
    final directory = await getTemporaryDirectory();
    final cleaned = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      '${directory.path}/${_uuid.v4()}.jpg',
      minWidth: purpose.shortSide,
      minHeight: purpose.shortSide,
      quality: 80,
    );
    // The picker's copy still has the metadata and is not needed anymore.
    await _deleteQuietly(File(picked.path));
    return cleaned?.path;
  }

  /// Deletes a photo this picker returned once it is not needed anymore.
  Future<void> discard(String path) => _deleteQuietly(File(path));

  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Left for the system to clear with the rest of the cache.
    }
  }
}
