import 'dart:async';

import 'package:http/http.dart' show ClientException;
import 'package:salahly/core/error/failure.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Whether [error] means the server could not be reached.
bool isNetworkError(Object error) =>
    error is ClientException ||
    error is TimeoutException ||
    error is AuthRetryableFetchException;

/// Maps errors every Supabase call can throw. Repositories handle their
/// feature-specific errors first and delegate the rest here.
Failure commonFailureFrom(Object error) {
  if (isNetworkError(error)) return const NetworkFailure();
  if (error is AuthException && error.statusCode == '429') {
    return const RateLimitedFailure();
  }
  return UnexpectedFailure(error);
}
