import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

PostgrestException _raised(String message) =>
    PostgrestException(message: message, code: 'P0001');

void main() {
  group('adminFailureFrom', () {
    const named = <String, Failure>{
      'admin_required': AdminRequiredFailure(),
      'recent_login_required': RecentLoginRequiredFailure(),
      'not_pending': NotPendingFailure(),
      'verification_not_found': AdminNotFoundFailure(),
      'topup_not_found': AdminNotFoundFailure(),
      'complaint_not_found': AdminNotFoundFailure(),
      'user_not_found': AdminNotFoundFailure(),
      'pack_not_found': AdminNotFoundFailure(),
      'account_not_found': AdminNotFoundFailure(),
      'area_not_found': AdminNotFoundFailure(),
      'invalid_reason': InvalidInputFailure(),
      'invalid_value': InvalidInputFailure(),
      'invalid_filter': InvalidInputFailure(),
      'invalid_search': InvalidInputFailure(),
      'invalid_period': InvalidInputFailure(),
      'invalid_target': InvalidInputFailure(),
      'nothing_to_update': InvalidInputFailure(),
      'duplicate_pack': DuplicateFailure(),
      'duplicate_area': DuplicateFailure(),
      'last_active_pack': LastActiveFailure(),
      'last_active_account': LastActiveFailure(),
      'cannot_suspend_admin': CannotSuspendAdminFailure(),
    };

    for (final MapEntry(key: message, value: failure) in named.entries) {
      test('reads $message', () {
        expect(adminFailureFrom(_raised(message)), failure);
      });
    }

    test('leaves the rest to the common mapping', () {
      expect(
        adminFailureFrom(_raised('something_else')),
        isA<UnexpectedFailure>(),
      );
      expect(
        adminFailureFrom(TimeoutException('slow')),
        const NetworkFailure(),
      );
    });
  });
}
