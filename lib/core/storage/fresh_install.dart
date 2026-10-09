import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Wipes secure storage on the first launch after an install.
///
/// iOS keeps Keychain items after the app is deleted, so a reinstall would
/// sign the previous owner of the phone back in. App files are deleted with
/// the app, so a missing marker file means a fresh install.
Future<void> clearSecureStorageAfterReinstall(
  FlutterSecureStorage storage,
) async {
  final directory = await getApplicationSupportDirectory();
  final marker = File('${directory.path}/.installed');
  if (marker.existsSync()) return;
  await storage.deleteAll();
  await marker.create(recursive: true);
}
