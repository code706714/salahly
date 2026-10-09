import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/media/photo_uploader.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/data/models/balance_models.dart';
import 'package:salahly/features/balance/data/repositories/balance_errors.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/domain/repositories/balance_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBalanceRepository implements BalanceRepository {
  SupabaseBalanceRepository(this._client) : _photos = PhotoUploader(_client);

  final SupabaseClient _client;
  final PhotoUploader _photos;

  static const _proofBucket = 'transfer-proofs';

  /// How many transfers and movements the history shows.
  static const historyLimit = 50;

  @override
  Future<Result<List<CreditPack>>> fetchPacks(UserRole role) => _call(() async {
    final rows = await _client
        .from('credit_packs')
        .select(BalanceModels.packSelect)
        .eq('role', toWire(role))
        .order('sort_order', ascending: true)
        .order('uses', ascending: true);
    return rows.map(BalanceModels.pack).toList();
  });

  @override
  Future<Result<List<PaymentAccount>>> fetchPaymentAccounts() =>
      _call(() async {
        final rows = await _client
            .from('payment_accounts')
            .select(BalanceModels.accountSelect);
        return rows.map(BalanceModels.account).toList();
      });

  @override
  Future<Result<List<Topup>>> fetchTopups(UserRole role) => _call(() async {
    final rows = await _client
        .from('credit_topups')
        .select(BalanceModels.topupSelect)
        .eq('role', toWire(role))
        .order('created_at', ascending: false)
        .limit(historyLimit);
    return rows.map(BalanceModels.topup).toList();
  });

  @override
  Future<Result<List<LedgerEntry>>> fetchLedger(UserRole role) =>
      _call(() async {
        final rows = await _client
            .from('credit_ledger')
            .select(BalanceModels.ledgerSelect)
            .eq('role', toWire(role))
            .order('created_at', ascending: false)
            .order('id', ascending: false)
            .limit(historyLimit);
        return rows.map(BalanceModels.ledgerEntry).toList();
      });

  @override
  Future<Result<String>> uploadScreenshot(String localPath) =>
      _photos.upload(localPath, bucket: _proofBucket);

  @override
  Future<Result<String>> submitTopup({
    required String packId,
    required int expectedPricePiastres,
    required TopupMethod method,
    required String senderAccount,
    required String screenshotPath,
  }) => _call(
    () => _client.rpc<String>(
      'submit_topup',
      params: {
        'p_pack_id': packId,
        'p_method': toWire(method),
        'p_sender_account': senderAccount,
        'p_screenshot_path': screenshotPath,
        'p_expected_price_piastres': expectedPricePiastres,
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

  static Failure _failureFrom(Object error) =>
      balanceFailureFrom(error) ?? commonFailureFrom(error);
}
