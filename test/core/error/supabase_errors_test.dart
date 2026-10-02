import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' show ClientException;
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  final networkErrors = <Object>[
    ClientException('Connection refused'),
    TimeoutException('No response'),
    AuthRetryableFetchException(),
  ];

  group('isNetworkError', () {
    for (final error in networkErrors) {
      test('is true for ${error.runtimeType}', () {
        expect(isNetworkError(error), isTrue);
      });
    }

    test('is false for an error the server answered with', () {
      const error = AuthApiException('Bad request', statusCode: '400');

      expect(isNetworkError(error), isFalse);
    });

    test('is false for an unrelated error', () {
      expect(isNetworkError(StateError('boom')), isFalse);
    });
  });

  group('commonFailureFrom', () {
    for (final error in networkErrors) {
      test('maps ${error.runtimeType} to NetworkFailure', () {
        expect(commonFailureFrom(error), const NetworkFailure());
      });
    }

    test('maps an AuthException with status 429 to RateLimitedFailure', () {
      const error = AuthException('Too many requests', statusCode: '429');

      expect(commonFailureFrom(error), const RateLimitedFailure());
    });

    test('maps an AuthApiException with status 429 to RateLimitedFailure', () {
      const error = AuthApiException(
        'Request rate limit reached',
        statusCode: '429',
        code: 'over_request_rate_limit',
      );

      expect(commonFailureFrom(error), const RateLimitedFailure());
    });

    test('maps any other AuthException to UnexpectedFailure', () {
      const error = AuthApiException('Bad request', statusCode: '400');

      expect(commonFailureFrom(error), const UnexpectedFailure(error));
    });

    test('keeps the cause of an unanticipated error', () {
      final error = StateError('boom');

      expect(commonFailureFrom(error), UnexpectedFailure(error));
    });
  });
}
