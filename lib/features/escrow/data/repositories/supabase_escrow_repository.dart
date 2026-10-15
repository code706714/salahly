import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/escrow/data/models/escrow_models.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/escrow/domain/failures/escrow_failures.dart';
import 'package:salahly/features/escrow/domain/repositories/escrow_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseEscrowRepository implements EscrowRepository {
  SupabaseEscrowRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<EscrowInfo?>> fetchInfo(String requestId) => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>?>(
      'escrow_info',
      params: {'p_request_id': requestId},
    );
    return json == null ? null : EscrowModels.info(json);
  });

  @override
  Future<Result<void>> confirmWork(String requestId) => _call(
    () => _client.rpc<void>(
      'confirm_work_done',
      params: {'p_request_id': requestId},
    ),
  );

  @override
  Future<Result<void>> dispute(String requestId, String reason) => _call(
    () => _client.rpc<void>(
      'dispute_payment',
      params: {'p_request_id': requestId, 'p_reason': reason},
    ),
  );

  @override
  Future<Result<TechnicianEscrow?>> fetchTechnicianEscrow(String requestId) =>
      _call(() async {
        final json = await _client.rpc<Map<String, dynamic>?>(
          'technician_escrow',
          params: {'p_request_id': requestId},
        );
        return json == null ? null : EscrowModels.technicianEscrow(json);
      });

  @override
  Future<Result<PayoutAccount?>> fetchPayoutAccount() => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>?>('my_payout_account');
    return json == null ? null : EscrowModels.payoutAccount(json);
  });

  @override
  Future<Result<void>> savePayoutAccount(PayoutAccount account) => _call(
    () => _client.rpc<void>(
      'save_payout_account',
      params: {
        'p_method': toWire(account.method),
        'p_account': account.account,
        'p_holder_name': account.holderName,
      },
    ),
  );

  static Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on Object catch (error) {
      return Err<T>(_failureFrom(error));
    }
  }

  static Failure _failureFrom(Object error) {
    if (error is PostgrestException) {
      switch (error.message) {
        case 'not_found' || 'escrow_unavailable':
          return const EscrowUnavailableFailure();
        case 'already_secured':
          return const AlreadySecuredFailure();
        case 'invalid_holder':
          return const InvalidHolderFailure();
        case 'invalid_account':
          return const InvalidPayoutAccountFailure();
        case 'invalid_reason':
          return const InvalidReasonFailure();
        case 'rate_limited':
          return const RateLimitedFailure();
      }
    }
    return commonFailureFrom(error);
  }
}
