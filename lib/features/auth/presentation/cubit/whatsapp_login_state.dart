part of 'whatsapp_login_cubit.dart';

enum WhatsappLoginPhase {
  /// Nothing started: the person has not pressed the button yet.
  idle,

  /// Asking the server for a code.
  starting,

  /// The code is out; waiting for the person's message.
  waiting,

  /// The message arrived; signing in.
  signingIn,

  /// Nobody sent the code in time.
  expired,
}

final class WhatsappLoginState extends Equatable {
  const WhatsappLoginState({
    this.phase = WhatsappLoginPhase.idle,
    this.challenge,
    this.couldNotOpenWhatsapp = false,
    this.failure,
  });

  final WhatsappLoginPhase phase;

  /// The code being waited for, from [WhatsappLoginPhase.waiting] on.
  final WhatsappLoginChallenge? challenge;

  /// WhatsApp did not open, so the person must send the code themselves.
  final bool couldNotOpenWhatsapp;

  /// Why starting or signing in failed, if it did.
  final Failure? failure;

  WhatsappLoginState copyWith({bool? couldNotOpenWhatsapp}) {
    return WhatsappLoginState(
      phase: phase,
      challenge: challenge,
      couldNotOpenWhatsapp: couldNotOpenWhatsapp ?? this.couldNotOpenWhatsapp,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [phase, challenge, couldNotOpenWhatsapp, failure];
}
