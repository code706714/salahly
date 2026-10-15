import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

/// The packs on sale and the record of the balance. Paying for a pack goes
/// through `PaymentRepository`; the server adds the uses once it is confirmed.
abstract interface class BalanceRepository {
  /// The packs on sale to [role], cheapest first.
  Future<Result<List<CreditPack>>> fetchPacks(UserRole role);

  /// The latest transfers of [role] made the old way (by screenshot), newest
  /// first. Kept so earlier purchases still show.
  Future<Result<List<Topup>>> fetchTopups(UserRole role);

  /// The latest movements of the [role]'s balance, newest first.
  Future<Result<List<LedgerEntry>>> fetchLedger(UserRole role);
}
