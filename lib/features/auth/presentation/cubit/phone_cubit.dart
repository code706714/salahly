import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';

part 'phone_state.dart';

class PhoneCubit extends Cubit<PhoneState> {
  PhoneCubit(this._authRepository) : super(const PhoneState());

  final AuthRepository _authRepository;

  void numberChanged(String input) {
    // The number being sent stays the one the code screen verifies.
    if (state.status == PhoneStatus.sending) return;
    emit(
      state.copyWith(
        digits: digitsOnly(input),
        status: PhoneStatus.editing,
        showInvalid: false,
        failure: () => null,
      ),
    );
  }

  Future<void> sendCode(OtpChannel channel) async {
    if (state.status == PhoneStatus.sending) return;
    final phone = state.phone;
    if (phone == null) {
      emit(state.copyWith(showInvalid: true, failure: () => null));
      return;
    }
    emit(
      state.copyWith(
        status: PhoneStatus.sending,
        channel: channel,
        failure: () => null,
      ),
    );
    final result = await _authRepository.requestOtp(
      phone: phone,
      channel: channel,
    );
    if (isClosed) return;
    emit(switch (result) {
      Ok() => state.copyWith(status: PhoneStatus.codeSent),
      Err(:final failure) => state.copyWith(
        status: PhoneStatus.editing,
        failure: () => failure,
      ),
    });
  }
}
