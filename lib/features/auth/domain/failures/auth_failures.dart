import 'package:salahly/core/error/failure.dart';

/// Signing in with WhatsApp is not available now: not set up yet, or too
/// many people are signing in at once.
final class WhatsappLoginUnavailableFailure extends Failure {
  const WhatsappLoginUnavailableFailure();
}

/// The sign-in ran out of time or was already used.
final class WhatsappLoginExpiredFailure extends Failure {
  const WhatsappLoginExpiredFailure();
}

/// The message came from another number than the one that must sign in.
final class WhatsappLoginWrongNumberFailure extends Failure {
  const WhatsappLoginWrongNumberFailure();
}
