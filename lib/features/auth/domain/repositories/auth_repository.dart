import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';

abstract interface class AuthRepository {
  /// The signed-in user now, then on every sign in or sign out.
  Stream<AuthUser?> get userChanges;

  AuthUser? get currentUser;

  /// Sends a one-time code, creating the account on first sign in.
  Future<Result<void>> requestOtp({
    required PhoneNumber phone,
    required OtpChannel channel,
  });

  /// Signs in with the code sent to [phone].
  Future<Result<void>> verifyOtp({
    required PhoneNumber phone,
    required String code,
  });

  Future<void> signOut();
}
