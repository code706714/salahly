import 'package:salahly/core/error/failure.dart';

/// A new code was asked for before the resend cooldown ended.
final class OtpTooSoonFailure extends Failure {
  const OtpTooSoonFailure();
}

/// The messaging provider could not deliver the code to this number.
final class OtpDeliveryFailure extends Failure {
  const OtpDeliveryFailure();
}

/// The code is wrong or has expired.
final class InvalidOtpFailure extends Failure {
  const InvalidOtpFailure();
}
