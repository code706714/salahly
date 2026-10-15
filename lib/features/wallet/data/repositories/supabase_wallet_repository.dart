import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/data/models/wallet_models.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';
import 'package:salahly/features/wallet/domain/failures/wallet_failures.dart';
import 'package:salahly/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseWalletRepository implements WalletRepository {
  SupabaseWalletRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<Result<Wallet>> fetch() => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>>('my_wallet');
    return WalletModels.wallet(json);
  });

  @override
  Future<Result<void>> requestWithdrawal({
    required int amountPiastres,
    required TopupMethod method,
    required String account,
    required String holderName,
  }) => _call(
    () => _client.rpc<void>(
      'request_withdrawal',
      params: {
        'p_amount_piastres': amountPiastres,
        'p_method': toWire(method),
        'p_account': account,
        'p_holder_name': holderName,
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
        case 'amount_too_small':
          return const AmountTooSmallFailure();
        case 'insufficient_balance':
          return const InsufficientBalanceFailure();
        case 'invalid_holder':
          return const InvalidHolderFailure();
        case 'invalid_account':
          return const InvalidWithdrawalAccountFailure();
        case 'rate_limited':
          return const RateLimitedFailure();
      }
    }
    return commonFailureFrom(error);
  }
}
