import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._auth);

  final supabase.GoTrueClient _auth;

  @override
  Stream<AuthUser?> get userChanges => _auth.onAuthStateChange
      .map((state) => _toAuthUser(state.session?.user))
      .distinct();

  @override
  AuthUser? get currentUser => _toAuthUser(_auth.currentUser);

  @override
  Future<Result<void>> requestOtp({
    required PhoneNumber phone,
    required OtpChannel channel,
  }) async {
    try {
      await _auth.signInWithOtp(
        phone: phone.e164,
        channel: switch (channel) {
          OtpChannel.whatsapp => supabase.OtpChannel.whatsapp,
          OtpChannel.sms => supabase.OtpChannel.sms,
        },
      );
      return const Ok(null);
    } on supabase.AuthRetryableFetchException catch (error) {
      // The server answered with a 5xx: usually the messaging provider.
      return Err(
        error.statusCode == null
            ? const NetworkFailure()
            : const OtpDeliveryFailure(),
      );
    } on Object catch (error) {
      return Err(_failureFrom(error));
    }
  }

  @override
  Future<Result<void>> verifyOtp({
    required PhoneNumber phone,
    required String code,
  }) async {
    try {
      await _auth.verifyOTP(
        phone: phone.e164,
        token: code,
        type: supabase.OtpType.sms,
      );
      return const Ok(null);
    } on Object catch (error) {
      return Err(_failureFrom(error));
    }
  }

  /// Signs out on this phone straight away, even offline. Telling the server
  /// comes after and may fail; the session it keeps expires on its own.
  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } on supabase.AuthException {
      // Already signed out here; only telling the server failed.
    }
  }

  static AuthUser? _toAuthUser(supabase.User? user) =>
      user == null ? null : AuthUser(id: user.id, phone: user.phone);

  // Codes: https://supabase.com/docs/guides/auth/debugging/error-codes
  static Failure _failureFrom(Object error) {
    if (error is supabase.AuthApiException) {
      switch (error.code) {
        case 'over_sms_send_rate_limit':
          return const OtpTooSoonFailure();
        case 'sms_send_failed':
          return const OtpDeliveryFailure();
        case 'otp_expired':
          return const InvalidOtpFailure();
      }
    }
    return commonFailureFrom(error);
  }
}
