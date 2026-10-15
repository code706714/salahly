import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/data/models/balance_models.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/balance/domain/repositories/balance_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseBalanceRepository implements BalanceRepository {
  SupabaseBalanceRepository(this._client);

  final SupabaseClient _client;

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

  static Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on Object catch (error) {
      return Err<T>(_failureFrom(error));
    }
  }

  static Failure _failureFrom(Object error) => commonFailureFrom(error);
}
