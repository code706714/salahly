import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/entities/phone_number.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/auth/presentation/cubit/phone_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  const validDigits = '1002345678';
  final phone = PhoneNumber.tryParse(validDigits)!;
  late AuthRepository authRepository;

  setUpAll(() {
    registerFallbackValue(phone);
    registerFallbackValue(OtpChannel.whatsapp);
  });

  setUp(() {
    authRepository = _MockAuthRepository();
  });

  PhoneCubit buildCubit({Result<void>? requestOtpResult}) {
    if (requestOtpResult != null) {
      when(
        () => authRepository.requestOtp(
          phone: any(named: 'phone'),
          channel: any(named: 'channel'),
        ),
      ).thenAnswer((_) async => requestOtpResult);
    }
    return PhoneCubit(authRepository);
  }

  void verifyNoCodeRequested() => verifyNever(
    () => authRepository.requestOtp(
      phone: any(named: 'phone'),
      channel: any(named: 'channel'),
    ),
  );

  test('starts editing an empty number with WhatsApp selected', () async {
    final cubit = buildCubit();

    expect(cubit.state, const PhoneState());
    expect(cubit.state.channel, OtpChannel.whatsapp);
    await cubit.close();
  });

  group('numberChanged', () {
    blocTest<PhoneCubit, PhoneState>(
      'keeps only the digits, read as ASCII',
      build: buildCubit,
      act: (cubit) => cubit.numberChanged('١٠٠ ٢٣٤ 5678'),
      expect: () => [const PhoneState(digits: validDigits)],
    );

    blocTest<PhoneCubit, PhoneState>(
      'does not flag an incomplete number while typing',
      build: buildCubit,
      act: (cubit) => cubit
        ..numberChanged('1')
        ..numberChanged('13'),
      expect: () => [
        const PhoneState(digits: '1'),
        const PhoneState(digits: '13'),
      ],
    );

    blocTest<PhoneCubit, PhoneState>(
      'clears the invalid flag',
      build: buildCubit,
      seed: () => const PhoneState(digits: '13', showInvalid: true),
      act: (cubit) => cubit.numberChanged('130'),
      expect: () => [const PhoneState(digits: '130')],
    );

    blocTest<PhoneCubit, PhoneState>(
      'clears the last failure',
      build: buildCubit,
      seed: () =>
          const PhoneState(digits: validDigits, failure: NetworkFailure()),
      act: (cubit) => cubit.numberChanged('100234567'),
      expect: () => [const PhoneState(digits: '100234567')],
    );

    blocTest<PhoneCubit, PhoneState>(
      'returns to editing after a code was sent',
      build: buildCubit,
      seed: () => const PhoneState(
        digits: validDigits,
        status: PhoneStatus.codeSent,
        channel: OtpChannel.sms,
      ),
      act: (cubit) => cubit.numberChanged('100234567'),
      expect: () => [
        const PhoneState(digits: '100234567', channel: OtpChannel.sms),
      ],
    );
  });

  group('sendCode', () {
    test('ignores edits while the code is being sent', () async {
      final sent = Completer<Result<void>>();
      when(
        () => authRepository.requestOtp(
          phone: any(named: 'phone'),
          channel: any(named: 'channel'),
        ),
      ).thenAnswer((_) => sent.future);
      final cubit = buildCubit()..numberChanged(validDigits);

      final sending = cubit.sendCode(OtpChannel.whatsapp);
      cubit.numberChanged('12');
      sent.complete(const Ok(null));
      await sending;

      expect(cubit.state.status, PhoneStatus.codeSent);
      expect(cubit.state.phone, phone);
      await cubit.close();
    });

    test('does not emit when the screen closes mid-send', () async {
      final sent = Completer<Result<void>>();
      when(
        () => authRepository.requestOtp(
          phone: any(named: 'phone'),
          channel: any(named: 'channel'),
        ),
      ).thenAnswer((_) => sent.future);
      final cubit = buildCubit()..numberChanged(validDigits);

      final sending = cubit.sendCode(OtpChannel.whatsapp);
      await cubit.close();
      sent.complete(const Ok(null));

      await expectLater(sending, completes);
    });

    blocTest<PhoneCubit, PhoneState>(
      'flags an invalid number only once the user tries to send',
      build: buildCubit,
      act: (cubit) async {
        cubit.numberChanged('130');
        await cubit.sendCode(OtpChannel.whatsapp);
      },
      expect: () => [
        const PhoneState(digits: '130'),
        const PhoneState(digits: '130', showInvalid: true),
      ],
      verify: (_) => verifyNoCodeRequested(),
    );

    blocTest<PhoneCubit, PhoneState>(
      'flags an empty number as invalid',
      build: buildCubit,
      act: (cubit) => cubit.sendCode(OtpChannel.whatsapp),
      expect: () => [const PhoneState(showInvalid: true)],
      verify: (_) => verifyNoCodeRequested(),
    );

    blocTest<PhoneCubit, PhoneState>(
      'replaces the last failure with the invalid flag',
      build: buildCubit,
      seed: () => const PhoneState(digits: '130', failure: NetworkFailure()),
      act: (cubit) => cubit.sendCode(OtpChannel.whatsapp),
      expect: () => [const PhoneState(digits: '130', showInvalid: true)],
    );

    blocTest<PhoneCubit, PhoneState>(
      'requests a code over the chosen channel and reports it sent',
      build: () => buildCubit(requestOtpResult: const Ok(null)),
      seed: () => const PhoneState(digits: validDigits),
      act: (cubit) => cubit.sendCode(OtpChannel.sms),
      expect: () => [
        const PhoneState(
          digits: validDigits,
          status: PhoneStatus.sending,
          channel: OtpChannel.sms,
        ),
        const PhoneState(
          digits: validDigits,
          status: PhoneStatus.codeSent,
          channel: OtpChannel.sms,
        ),
      ],
      verify: (_) => verify(
        () => authRepository.requestOtp(phone: phone, channel: OtpChannel.sms),
      ).called(1),
    );

    blocTest<PhoneCubit, PhoneState>(
      'clears the last failure when sending again',
      build: () => buildCubit(requestOtpResult: const Ok(null)),
      seed: () =>
          const PhoneState(digits: validDigits, failure: NetworkFailure()),
      act: (cubit) => cubit.sendCode(OtpChannel.whatsapp),
      expect: () => [
        const PhoneState(digits: validDigits, status: PhoneStatus.sending),
        const PhoneState(digits: validDigits, status: PhoneStatus.codeSent),
      ],
    );

    for (final failure in const <Failure>[
      OtpTooSoonFailure(),
      OtpDeliveryFailure(),
      NetworkFailure(),
      RateLimitedFailure(),
    ]) {
      blocTest<PhoneCubit, PhoneState>(
        'returns to editing with ${failure.runtimeType}, keeping the channel',
        build: () => buildCubit(requestOtpResult: Err(failure)),
        seed: () => const PhoneState(digits: validDigits),
        act: (cubit) => cubit.sendCode(OtpChannel.sms),
        expect: () => [
          const PhoneState(
            digits: validDigits,
            status: PhoneStatus.sending,
            channel: OtpChannel.sms,
          ),
          PhoneState(
            digits: validDigits,
            channel: OtpChannel.sms,
            failure: failure,
          ),
        ],
      );
    }

    blocTest<PhoneCubit, PhoneState>(
      'ignores a send while another is in flight',
      build: buildCubit,
      seed: () => const PhoneState(
        digits: validDigits,
        status: PhoneStatus.sending,
      ),
      act: (cubit) => cubit.sendCode(OtpChannel.sms),
      expect: () => <PhoneState>[],
      verify: (_) => verifyNoCodeRequested(),
    );
  });
}
