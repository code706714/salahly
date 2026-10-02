part of 'otp_cubit.dart';

enum OtpStatus { entering, verifying, verified }

final class OtpState extends Equatable {
  const OtpState({
    this.code = '',
    this.status = OtpStatus.entering,
    this.resendIn = OtpCubit.resendCooldown,
    this.isResending = false,
    this.resendCount = 0,
    this.failure,
  });

  /// The digits entered so far, at most [OtpCubit.codeLength].
  final String code;
  final OtpStatus status;

  /// Seconds until another code can be requested; 0 means now.
  final int resendIn;
  final bool isResending;

  /// Increases on every successful resend, so the page can confirm it.
  final int resendCount;

  /// Why the last verify or resend failed, if it did.
  final Failure? failure;

  bool get isComplete => code.length == OtpCubit.codeLength;

  OtpState copyWith({
    String? code,
    OtpStatus? status,
    int? resendIn,
    bool? isResending,
    int? resendCount,
    Failure? Function()? failure,
  }) {
    return OtpState(
      code: code ?? this.code,
      status: status ?? this.status,
      resendIn: resendIn ?? this.resendIn,
      isResending: isResending ?? this.isResending,
      resendCount: resendCount ?? this.resendCount,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    code,
    status,
    resendIn,
    isResending,
    resendCount,
    failure,
  ];
}
