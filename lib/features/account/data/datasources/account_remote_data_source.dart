import 'package:salahly/features/account/data/models/user_profile_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRemoteDataSource {
  AccountRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Deletes the account on the server; the word is what it needs to be
  /// sure the person confirmed.
  Future<void> deleteAccount() => _client.rpc<void>(
    'delete_my_account',
    params: {'p_confirmation': 'DELETE'},
  );

  /// The profile row with its side profiles, or null before onboarding.
  Future<Map<String, dynamic>?> fetchProfile(String userId) {
    return _client
        .from('profiles')
        .select(UserProfileModel.select)
        .eq('id', userId)
        .maybeSingle();
  }
}
