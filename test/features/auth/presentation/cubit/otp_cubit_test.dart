import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/auth/presentation/cubit/otp_cubit.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  final phone = PhoneNumber.tryParse('1002345678')!;
  late AuthRepository authRepository;

  setUpAll(() {
    registerFallbackValue(phone);
    registerFallbackValue(OtpChannel.whatsapp);
  });

  setUp(() {
    authRepository = _MockAuthRepository();
  });

  void stubVerifyOtp(Future<Result<void>> Function() answer) {
    when(
      () => authRepository.verifyOtp(
        phone: any(named: 'phone'),
        code: any(named: 'code'),
      ),
    ).thenAnswer((_) => answer());
  }

  void stubRequestOtp(Future<Result<void>> Function() answer) {
    when(
      () => authRepository.requestOtp(
        phone: any(named: 'phone'),
        channel: any(named: 'channel'),
      ),
    ).thenAnswer((_) => answer());
  }

  OtpCubit buildCubit() => OtpCubit(
    authRepository: authRepository,
    phone: phone,
    channel: OtpChannel.whatsapp,
  );

  OtpCubit buildVerifyingCubit([Result<void> result = const Ok(null)]) {
    stubVerifyOtp(() async => result);
    return buildCubit();
  }

  OtpCubit buildResendingCubit(Result<void> result) {
    stubRequestOtp(() async => result);
    return buildCubit();
  }

  void verifyCodeChecked(String code) => verify(
    () => authRepository.verifyOtp(phone: phone, code: code),
  ).called(1);

  void verifyNoCodeChecked() => verifyNever(
    () => authRepository.verifyOtp(
      phone: any(named: 'phone'),
      code: any(named: 'code'),
    ),
  );

  void verifyNoCodeRequested() => verifyNever(
    () => authRepository.requestOtp(
      phone: any(named: 'phone'),
      channel: any(named: 'channel'),
    ),
  );

  List<OtpState> verifiedFlow(String code) => [
    OtpState(code: code),
    OtpState(code: code, status: OtpStatus.verifying),
    OtpState(code: code, status: OtpStatus.verified),
  ];

  test('starts with an empty code and the full resend cooldown', () async {
    final cubit = buildCubit();

    expect(cubit.state, const OtpState());
    expect(cubit.state.resendIn, 60);
    await cubit.close();
  });

  group('digitEntered', () {
    blocTest<OtpCubit, OtpState>(
      'appends each digit',
      build: buildCubit,
      act: (cubit) => cubit
        ..digitEntered('1')
        ..digitEntered('2'),
      expect: () => [
        const OtpState(code: '1'),
        const OtpState(code: '12'),
      ],
      verify: (_) => verifyNoCodeChecked(),
    );

    blocTest<OtpCubit, OtpState>(
      'verifies the code as soon as the sixth digit is entered',
      build: buildVerifyingCubit,
      seed: () => const OtpState(code: '12345'),
      act: (cubit) => cubit.digitEntered('6'),
      expect: () => verifiedFlow('123456'),
      verify: (_) => verifyCodeChecked('123456'),
    );

    blocTest<OtpCubit, OtpState>(
      'ignores digits beyond the sixth',
      build: buildCubit,
      seed: () => const OtpState(code: '123456'),
      act: (cubit) => cubit.digitEntered('7'),
      expect: () => <OtpState>[],
    );

    blocTest<OtpCubit, OtpState>(
      'clears the last failure',
      build: buildCubit,
      seed: () => const OtpState(failure: InvalidOtpFailure()),
      act: (cubit) => cubit.digitEntered('1'),
      expect: () => [const OtpState(code: '1')],
    );
  });

  group('digitDeleted', () {
    blocTest<OtpCubit, OtpState>(
      'removes the last digit',
      build: buildCubit,
      seed: () => const OtpState(code: '123'),
      act: (cubit) => cubit.digitDeleted(),
      expect: () => [const OtpState(code: '12')],
    );

    blocTest<OtpCubit, OtpState>(
      'does nothing when the code is empty',
      build: buildCubit,
      act: (cubit) => cubit.digitDeleted(),
      expect: () => <OtpState>[],
    );
  });

  group('codePasted', () {
    blocTest<OtpCubit, OtpState>(
      'fills the code from a pasted message and verifies it',
      build: buildVerifyingCubit,
      act: (cubit) => cubit.codePasted('كود صلحلي: 123456'),
      expect: () => verifiedFlow('123456'),
      verify: (_) => verifyCodeChecked('123456'),
    );

    blocTest<OtpCubit, OtpState>(
      'reads Arabic-Indic digits as ASCII',
      build: buildVerifyingCubit,
      act: (cubit) => cubit.codePasted('كود صلحلي: ٦٥٤٣٢١'),
      expect: () => verifiedFlow('654321'),
      verify: (_) => verifyCodeChecked('654321'),
    );

    blocTest<OtpCubit, OtpState>(
      'takes the first six digits when the text has more',
      build: buildVerifyingCubit,
      act: (cubit) => cubit.codePasted('123456 صالح لمدة 10 دقائق'),
      expect: () => verifiedFlow('123456'),
    );

    blocTest<OtpCubit, OtpState>(
      'replaces a partly typed code',
      build: buildVerifyingCubit,
      seed: () => const OtpState(code: '98'),
      act: (cubit) => cubit.codePasted('123456'),
      expect: () => verifiedFlow('123456'),
    );

    blocTest<OtpCubit, OtpState>(
      'ignores text with fewer than six digits',
      build: buildCubit,
      seed: () => const OtpState(code: '98'),
      act: (cubit) => cubit.codePasted('كود 12345'),
      expect: () => <OtpState>[],
      verify: (_) => verifyNoCodeChecked(),
    );
  });

  group('verify', () {
    for (final failure in const <Failure>[
      InvalidOtpFailure(),
      NetworkFailure(),
      RateLimitedFailure(),
    ]) {
      blocTest<OtpCubit, OtpState>(
        'clears the code and reports ${failure.runtimeType}',
        build: () => buildVerifyingCubit(Err(failure)),
        seed: () => const OtpState(code: '12345'),
        act: (cubit) => cubit.digitEntered('6'),
        expect: () => [
          const OtpState(code: '123456'),
          const OtpState(code: '123456', status: OtpStatus.verifying),
          OtpState(failure: failure),
        ],
      );
    }

    blocTest<OtpCubit, OtpState>(
      'verifies a complete code on submit',
      build: buildVerifyingCubit,
      seed: () => const OtpState(code: '123456'),
      act: (cubit) => cubit.verify(),
      expect: () => const [
        OtpState(code: '123456', status: OtpStatus.verifying),
        OtpState(code: '123456', status: OtpStatus.verified),
      ],
      verify: (_) => verifyCodeChecked('123456'),
    );

    blocTest<OtpCubit, OtpState>(
      'does nothing for an incomplete code',
      build: buildCubit,
      seed: () => const OtpState(code: '12345'),
      act: (cubit) => cubit.verify(),
      expect: () => <OtpState>[],
      verify: (_) => verifyNoCodeChecked(),
    );

    for (final status in [OtpStatus.verifying, OtpStatus.verified]) {
      blocTest<OtpCubit, OtpState>(
        'ignores typing, deleting and pasting while ${status.name}',
        build: buildCubit,
        seed: () => OtpState(code: '123456', status: status),
        act: (cubit) async {
          cubit
            ..digitDeleted()
            ..digitEntered('1')
            ..codePasted('654321');
          await cubit.verify();
        },
        expect: () => <OtpState>[],
        verify: (_) => verifyNoCodeChecked(),
      );
    }
  });

  group('resend', () {
    blocTest<OtpCubit, OtpState>(
      'requests a new code and restarts the cooldown',
      build: () => buildResendingCubit(const Ok(null)),
      seed: () => const OtpState(code: '12', resendIn: 0),
      act: (cubit) => cubit.resend(),
      expect: () => [
        const OtpState(code: '12', resendIn: 0, isResending: true),
        const OtpState(code: '12', resendCount: 1),
      ],
      verify: (_) => verify(
        () => authRepository.requestOtp(
          phone: phone,
          channel: OtpChannel.whatsapp,
        ),
      ).called(1),
    );

    blocTest<OtpCubit, OtpState>(
      'clears the last failure as it starts',
      build: () => buildResendingCubit(const Ok(null)),
      seed: () => const OtpState(resendIn: 0, failure: InvalidOtpFailure()),
      act: (cubit) => cubit.resend(),
      expect: () => [
        const OtpState(resendIn: 0, isResending: true),
        const OtpState(resendCount: 1),
      ],
    );

    for (final failure in const <Failure>[
      OtpTooSoonFailure(),
      OtpDeliveryFailure(),
      NetworkFailure(),
      RateLimitedFailure(),
    ]) {
      blocTest<OtpCubit, OtpState>(
        'reports ${failure.runtimeType} and lets the user try again',
        build: () => buildResendingCubit(Err(failure)),
        seed: () => const OtpState(resendIn: 0),
        act: (cubit) => cubit.resend(),
        expect: () => [
          const OtpState(resendIn: 0, isResending: true),
          OtpState(resendIn: 0, failure: failure),
        ],
      );
    }

    blocTest<OtpCubit, OtpState>(
      'is blocked during the cooldown',
      build: buildCubit,
      seed: () => const OtpState(resendIn: 1),
      act: (cubit) => cubit.resend(),
      expect: () => <OtpState>[],
      verify: (_) => verifyNoCodeRequested(),
    );

    blocTest<OtpCubit, OtpState>(
      'ignores a resend while another is in flight',
      build: buildCubit,
      seed: () => const OtpState(resendIn: 0, isResending: true),
      act: (cubit) => cubit.resend(),
      expect: () => <OtpState>[],
      verify: (_) => verifyNoCodeRequested(),
    );
  });

  group('resend countdown', () {
    test('ticks once a second from 59 down to 0, then stops', () {
      fakeAsync((async) {
        final cubit = buildCubit();
        final remaining = <int>[];
        cubit.stream.listen((state) => remaining.add(state.resendIn));

        async.elapse(const Duration(seconds: 70));

        expect(remaining, [
          for (var second = 59; second >= 0; second--) second,
        ]);
        expect(async.periodicTimerCount, 0);
        unawaited(cubit.close());
      });
    });

    test('allows a resend only once the 60 seconds have passed', () {
      fakeAsync((async) {
        stubRequestOtp(() async => const Ok(null));
        final cubit = buildCubit();

        async.elapse(const Duration(seconds: 59));
        unawaited(cubit.resend());
        async.flushMicrotasks();
        verifyNoCodeRequested();

        async.elapse(const Duration(seconds: 1));
        unawaited(cubit.resend());
        async.flushMicrotasks();
        verify(
          () => authRepository.requestOtp(
            phone: phone,
            channel: OtpChannel.whatsapp,
          ),
        ).called(1);
        unawaited(cubit.close());
      });
    });

    test('counts down a fresh 60 seconds after a successful resend', () {
      fakeAsync((async) {
        stubRequestOtp(() async => const Ok(null));
        final cubit = buildCubit();
        async.elapse(const Duration(seconds: 60));

        unawaited(cubit.resend());
        async.flushMicrotasks();
        expect(cubit.state, const OtpState(resendCount: 1));

        async.elapse(const Duration(seconds: 1));
        expect(cubit.state.resendIn, 59);

        async.elapse(const Duration(seconds: 59));
        expect(cubit.state.resendIn, 0);
        expect(async.periodicTimerCount, 0);
        unawaited(cubit.close());
      });
    });

    test('stops when the cubit is closed', () {
      fakeAsync((async) {
        final cubit = buildCubit();
        expect(async.periodicTimerCount, 1);

        unawaited(cubit.close());
        async.flushMicrotasks();

        expect(async.periodicTimerCount, 0);
        async.elapse(const Duration(seconds: 5));
        expect(cubit.state.resendIn, 60);
      });
    });
  });

  group('after close', () {
    test('drops a verify result that arrives late', () async {
      final result = Completer<Result<void>>();
      stubVerifyOtp(() => result.future);
      final cubit = buildCubit()..codePasted('123456');

      await cubit.close();
      result.complete(const Ok(null));
      await pumpEventQueue();

      expect(
        cubit.state,
        const OtpState(code: '123456', status: OtpStatus.verifying),
      );
    });

    test('drops a resend result that arrives late', () {
      fakeAsync((async) {
        final result = Completer<Result<void>>();
        stubRequestOtp(() => result.future);
        final cubit = buildCubit();
        async.elapse(const Duration(seconds: 60));

        unawaited(cubit.resend());
        unawaited(cubit.close());
        async.flushMicrotasks();
        result.complete(const Ok(null));
        async.flushMicrotasks();

        expect(cubit.state, const OtpState(resendIn: 0, isResending: true));
        expect(async.periodicTimerCount, 0);
      });
    });
  });
}
