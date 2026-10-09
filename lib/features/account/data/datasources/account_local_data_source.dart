import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps the last fetched profile JSON in encrypted storage. It holds the
/// user's name and phone, so it never goes to plain preferences.
class AccountLocalDataSource {
  AccountLocalDataSource(this._storage);

  static const _key = 'account.profile';

  final FlutterSecureStorage _storage;

  Future<Map<String, dynamic>?> read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> write(Map<String, dynamic> json) =>
      _storage.write(key: _key, value: jsonEncode(json));

  Future<void> clear() => _storage.delete(key: _key);
}
