import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/features/account/data/datasources/account_local_data_source.dart';
import 'package:salahly/features/account/data/datasources/account_remote_data_source.dart';
import 'package:salahly/features/account/data/models/user_profile_model.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/account/domain/repositories/account_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepositoryImpl implements AccountRepository {
  AccountRepositoryImpl({required this._remote, required this._local});

  final AccountRemoteDataSource _remote;
  final AccountLocalDataSource _local;

  @override
  Future<UserProfile?> cachedProfile(String userId) async {
    try {
      final json = await _local.read();
      if (json == null || json['id'] != userId) return null;
      return UserProfileModel.fromJson(json);
    } on Object {
      // An unreadable or outdated cache is the same as no cache.
      await clearCache();
      return null;
    }
  }

  @override
  Future<Result<UserProfile?>> fetchProfile(String userId) async {
    final Map<String, dynamic>? json;
    final UserProfile? profile;
    try {
      json = await _remote.fetchProfile(userId);
      profile = json == null ? null : UserProfileModel.fromJson(json);
    } on Object catch (error) {
      return Err(commonFailureFrom(error));
    }
    if (json case final fetched?) {
      await _bestEffort(() => _local.write(fetched));
    } else {
      await clearCache();
    }
    return Ok(profile);
  }

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      await _remote.deleteAccount();
      return const Ok(null);
    } on PostgrestException catch (error) {
      return Err(switch (error.message) {
        'topup_pending' => const PendingTransferFailure(),
        'recent_login_required' => const RecentLoginRequiredFailure(),
        _ => commonFailureFrom(error),
      });
    } on Object catch (error) {
      return Err(commonFailureFrom(error));
    }
  }

  @override
  Future<void> clearCache() => _bestEffort(_local.clear);

  /// The cache only speeds up the next launch, so a storage error (some
  /// Android keystores fail) must never fail the caller.
  Future<void> _bestEffort(Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      // Ignored: the profile is fetched again on the next launch.
    }
  }
}
