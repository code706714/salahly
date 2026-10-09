part of 'phone_cubit.dart';

enum PhoneStatus { editing, sending, codeSent }

final class PhoneState extends Equatable {
  const PhoneState({
    this.digits = '',
    this.status = PhoneStatus.editing,
    this.channel = OtpChannel.whatsapp,
    this.showInvalid = false,
    this.failure,
  });

  /// What the user typed, digits only.
  final String digits;
  final PhoneStatus status;

  /// The channel of the last send attempt.
  final OtpChannel channel;

  /// The user tried to continue with a number that isn't an Egyptian mobile.
  final bool showInvalid;

  /// Why the last send failed, if it did.
  final Failure? failure;

  PhoneNumber? get phone => PhoneNumber.tryParse(digits);

  PhoneState copyWith({
    String? digits,
    PhoneStatus? status,
    OtpChannel? channel,
    bool? showInvalid,
    Failure? Function()? failure,
  }) {
    return PhoneState(
      digits: digits ?? this.digits,
      status: status ?? this.status,
      channel: channel ?? this.channel,
      showInvalid: showInvalid ?? this.showInvalid,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [digits, status, channel, showInvalid, failure];
}
