import 'package:equatable/equatable.dart';
import 'package:salahly/core/phone/phone_number.dart';

/// A sign-in that waits for the person's WhatsApp message: the [code] goes
/// in the message, WhatsApp tells the server which number sent it, and the
/// phone, which alone holds [pollSecret], then signs in as that number.
final class WhatsappLoginChallenge extends Equatable {
  const WhatsappLoginChallenge({
    required this.id,
    required this.code,
    required this.pollSecret,
    required this.expiresAt,
    required this.whatsappNumber,
  });

  final String id;

  /// What the message must carry, e.g. AB3D5FGH.
  final String code;

  /// Proves this phone started the sign-in; never shown or sent anywhere
  /// but back to the server.
  final String pollSecret;
  final DateTime expiresAt;

  /// The number the message goes to.
  final PhoneNumber whatsappNumber;

  @override
  List<Object?> get props => [
    id,
    code,
    pollSecret,
    expiresAt,
    whatsappNumber,
  ];
}

/// What the server knows about a [WhatsappLoginChallenge].
enum WhatsappLoginProgress {
  /// The message has not arrived yet.
  pending,

  /// The message arrived: the phone can sign in.
  ready,

  /// Nobody sent the code in time.
  expired,
}
