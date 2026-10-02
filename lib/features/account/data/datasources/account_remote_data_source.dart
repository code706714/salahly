import 'package:salahly/features/account/data/models/user_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRemoteDataSource {
  AccountRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// The profile row with its side profiles, or null before onboarding.
  Future<Map<String, dynamic>?> fetchProfile(String userId) {
    return _client
        .from('profiles')
        .select(UserProfileModel.select)
        .eq('id', userId)
        .maybeSingle();
  }
}
