import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/entities/whatsapp_login.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class _MockGoTrueClient extends Mock implements supabase.GoTrueClient {}

class _MockFunctionsClient extends Mock implements supabase.FunctionsClient {}

void main() {
  final phone = PhoneNumber.tryParse('1002345678')!;
  late supabase.GoTrueClient auth;
  late supabase.FunctionsClient functions;
  late SupabaseAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(supabase.OtpChannel.sms);
    registerFallbackValue(supabase.OtpType.sms);
  });

  setUp(() {
    auth = _MockGoTrueClient();
    functions = _MockFunctionsClient();
    repository = SupabaseAuthRepository(auth, functions);
  });

  Future<void> anySignInWithOtp() => auth.signInWithOtp(
    phone: any(named: 'phone'),
    channel: any(named: 'channel'),
  );

  Future<supabase.AuthResponse> anyVerifyOtp() => auth.verifyOTP(
    phone: any(named: 'phone'),
    token: any(named: 'token'),
    type: any(named: 'type'),
  );

  Matcher isErrWith(Failure failure) =>
      isA<Err<void>>().having((err) => err.failure, 'failure', failure);

  final commonErrors = <String, (Object, Failure)>{
    'a request rate limit': (
      const supabase.AuthApiException(
        'Request rate limit reached',
        statusCode: '429',
        code: 'over_request_rate_limit',
      ),
      const RateLimitedFailure(),
    ),
    'a retryable fetch error': (
      supabase.AuthRetryableFetchException(),
      const NetworkFailure(),
    ),
    'a client exception': (
      ClientException('Connection refused'),
      const NetworkFailure(),
    ),
  };

  group('requestOtp', () {
    for (final (channel, supabaseChannel) in [
      (OtpChannel.whatsapp, supabase.OtpChannel.whatsapp),
      (OtpChannel.sms, supabase.OtpChannel.sms),
    ]) {
      test('sends the E.164 number over ${channel.name}', () async {
        when(anySignInWithOtp).thenAnswer((_) async {});

        final result = await repository.requestOtp(
          phone: phone,
          channel: channel,
        );

        expect(result, isA<Ok<void>>());
        verify(
          () => auth.signInWithOtp(
            phone: '+201002345678',
            channel: supabaseChannel,
          ),
        ).called(1);
      });
    }

    final errors = <String, (Object, Failure)>{
      'over_sms_send_rate_limit': (
        const supabase.AuthApiException(
          'For security purposes, you can only request this after 42 seconds',
          statusCode: '429',
          code: 'over_sms_send_rate_limit',
        ),
        const OtpTooSoonFailure(),
      ),
      'sms_send_failed': (
        const supabase.AuthApiException(
          'Error sending confirmation OTP to provider',
          statusCode: '500',
          code: 'sms_send_failed',
        ),
        const OtpDeliveryFailure(),
      ),
      ...commonErrors,
    };

    for (final MapEntry(key: name, value: (error, failure)) in errors.entries) {
      test('maps $name to ${failure.runtimeType}', () async {
        when(anySignInWithOtp).thenThrow(error);

        final result = await repository.requestOtp(
          phone: phone,
          channel: OtpChannel.whatsapp,
        );

        expect(result, isErrWith(failure));
      });
    }

    test('keeps an unknown API error as the unexpected cause', () async {
      const error = supabase.AuthApiException(
        'Unsupported phone provider',
        statusCode: '400',
        code: 'sms_provider_disabled',
      );
      when(anySignInWithOtp).thenThrow(error);

      final result = await repository.requestOtp(
        phone: phone,
        channel: OtpChannel.sms,
      );

      expect(result, isErrWith(const UnexpectedFailure(error)));
    });
  });

  group('verifyOtp', () {
    test('verifies the code as an SMS OTP for the E.164 number', () async {
      when(anyVerifyOtp).thenAnswer((_) async => supabase.AuthResponse());

      final result = await repository.verifyOtp(phone: phone, code: '123456');

      expect(result, isA<Ok<void>>());
      verify(
        () => auth.verifyOTP(
          phone: '+201002345678',
          token: '123456',
          type: supabase.OtpType.sms,
        ),
      ).called(1);
    });

    final errors = <String, (Object, Failure)>{
      'otp_expired': (
        const supabase.AuthApiException(
          'Token has expired or is invalid',
          statusCode: '403',
          code: 'otp_expired',
        ),
        const InvalidOtpFailure(),
      ),
      ...commonErrors,
    };

    for (final MapEntry(key: name, value: (error, failure)) in errors.entries) {
      test('maps $name to ${failure.runtimeType}', () async {
        when(anyVerifyOtp).thenThrow(error);

        final result = await repository.verifyOtp(
          phone: phone,
          code: '123456',
        );

        expect(result, isErrWith(failure));
      });
    }
  });

  group('WhatsApp sign in', () {
    final challenge = WhatsappLoginChallenge(
      id: '11111111-2222-4333-8444-555555555555',
      code: 'AB3D5FGH',
      pollSecret: 'a' * 64,
      expiresAt: DateTime.utc(2026, 10, 14, 12),
      whatsappNumber: PhoneNumber.tryParse('1000000000')!,
    );

    Future<supabase.FunctionResponse> anyInvoke() => functions.invoke(
      'whatsapp-login',
      body: any(named: 'body'),
    );

    void answers(Object? data, {int status = 200}) {
      when(anyInvoke).thenAnswer(
        (_) async => supabase.FunctionResponse(data: data, status: status),
      );
    }

    Map<String, Object> sentBody() =>
        verify(
              () => functions.invoke(
                'whatsapp-login',
                body: captureAny(named: 'body'),
              ),
            ).captured.single
            as Map<String, Object>;

    test('start gives the code and the number to send it to', () async {
      answers({
        'id': challenge.id,
        'code': challenge.code,
        'pollSecret': challenge.pollSecret,
        'expiresAt': '2026-10-14T12:00:00Z',
        'whatsappNumber': '201000000000',
      });

      final result = await repository.startWhatsappLogin();

      expect(result, isA<Ok<WhatsappLoginChallenge>>());
      expect((result as Ok<WhatsappLoginChallenge>).value, challenge);
      expect(sentBody(), {'action': 'start'});
    });

    test('start without a usable WhatsApp number is unavailable', () async {
      answers({
        'id': challenge.id,
        'code': challenge.code,
        'pollSecret': challenge.pollSecret,
        'expiresAt': '2026-10-14T12:00:00Z',
        'whatsappNumber': '',
      });

      final result = await repository.startWhatsappLogin();

      expect(
        result,
        isA<Err<WhatsappLoginChallenge>>().having(
          (err) => err.failure,
          'failure',
          const WhatsappLoginUnavailableFailure(),
        ),
      );
    });

    final failures = <String, (Object, Failure)>{
      'a server that is not set up': (
        const supabase.FunctionException(status: 503),
        const WhatsappLoginUnavailableFailure(),
      ),
      'a sign in that ran out': (
        const supabase.FunctionException(status: 409),
        const WhatsappLoginExpiredFailure(),
      ),
      ...commonErrors,
    };
    for (final MapEntry(key: name, value: (error, failure))
        in failures.entries) {
      test('maps $name to ${failure.runtimeType}', () async {
        when(anyInvoke).thenThrow(error);

        expect(
          await repository.startWhatsappLogin(),
          isA<Err<WhatsappLoginChallenge>>().having(
            (err) => err.failure,
            'failure',
            failure,
          ),
        );
        expect(
          await repository.completeWhatsappLogin(challenge),
          isErrWith(failure),
        );
      });
    }

    test('a status of pending, ready or anything else', () async {
      for (final (status, progress) in [
        ('pending', WhatsappLoginProgress.pending),
        ('ready', WhatsappLoginProgress.ready),
        ('expired', WhatsappLoginProgress.expired),
        ('unknown', WhatsappLoginProgress.expired),
      ]) {
        answers({'status': status});

        final result = await repository.whatsappLoginProgress(challenge);

        expect(
          (result as Ok<WhatsappLoginProgress>).value,
          progress,
          reason: status,
        );
      }
    });

    test(
      'complete signs in with the number and its one-time password',
      () async {
        answers({'phone': '+201002345678', 'password': 'one-time'});
        when(
          () => auth.signInWithPassword(
            phone: any(named: 'phone'),
            password: any(named: 'password'),
          ),
        ).thenAnswer((_) async => supabase.AuthResponse());

        final result = await repository.completeWhatsappLogin(challenge);

        expect(result, isA<Ok<void>>());
        expect(sentBody(), {
          'action': 'complete',
          'id': challenge.id,
          'pollSecret': challenge.pollSecret,
        });
        verify(
          () => auth.signInWithPassword(
            phone: '+201002345678',
            password: 'one-time',
          ),
        ).called(1);
      },
    );

    test('complete fails when the password sign in is refused', () async {
      answers({'phone': '+201002345678', 'password': 'one-time'});
      const error = supabase.AuthApiException(
        'Invalid login credentials',
        statusCode: '400',
        code: 'invalid_credentials',
      );
      when(
        () => auth.signInWithPassword(
          phone: any(named: 'phone'),
          password: any(named: 'password'),
        ),
      ).thenThrow(error);

      expect(
        await repository.completeWhatsappLogin(challenge),
        isErrWith(const UnexpectedFailure(error)),
      );
    });
  });

  group('signOut', () {
    test('signs out through Supabase', () async {
      when(() => auth.signOut()).thenAnswer((_) async {});

      await repository.signOut();

      verify(() => auth.signOut()).called(1);
    });

    test('still signs out on the phone when the server is out of reach', () {
      when(
        () => auth.signOut(),
      ).thenThrow(supabase.AuthRetryableFetchException());

      expect(repository.signOut(), completes);
    });
  });
}
