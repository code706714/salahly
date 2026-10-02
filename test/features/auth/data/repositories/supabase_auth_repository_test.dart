import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

class _MockGoTrueClient extends Mock implements supabase.GoTrueClient {}

void main() {
  final phone = PhoneNumber.tryParse('1002345678')!;
  late supabase.GoTrueClient auth;
  late SupabaseAuthRepository repository;

  setUpAll(() {
    registerFallbackValue(supabase.OtpChannel.sms);
    registerFallbackValue(supabase.OtpType.sms);
  });

  setUp(() {
    auth = _MockGoTrueClient();
    repository = SupabaseAuthRepository(auth);
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
