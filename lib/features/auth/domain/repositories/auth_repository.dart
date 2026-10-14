import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/entities/whatsapp_login.dart';

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

  /// Starts a sign-in by WhatsApp message, creating the account on first
  /// sign in. Nothing is sent to the person, so it costs nothing.
  Future<Result<WhatsappLoginChallenge>> startWhatsappLogin();

  /// Whether the message for [challenge] has arrived.
  Future<Result<WhatsappLoginProgress>> whatsappLoginProgress(
    WhatsappLoginChallenge challenge,
  );

  /// Signs in as the number that sent the message for [challenge]. Works
  /// once, and only after the progress is ready.
  Future<Result<void>> completeWhatsappLogin(WhatsappLoginChallenge challenge);

  Future<void> signOut();
}
