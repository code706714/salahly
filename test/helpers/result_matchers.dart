import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/result.dart';

/// Matches an [Ok] whose value matches [value], which may be a matcher.
Matcher isOk([Object? value = anything]) =>
    isA<Ok<Object?>>().having((ok) => ok.value, 'value', value);

/// Matches an [Err] whose failure matches [failure], which may be a matcher.
Matcher isErr([Object? failure = anything]) =>
    isA<Err<Object?>>().having((err) => err.failure, 'failure', failure);
