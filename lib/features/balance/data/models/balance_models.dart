import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';

/// Maps the balance tables' JSON to domain entities.
abstract final class BalanceModels {
  static const packSelect = 'id, uses, price_piastres';
  static const accountSelect = 'method, account, holder_name';
  static const topupSelect =
      'id, uses, amount_piastres, method, status, reject_reason, created_at';
  static const ledgerSelect = 'id, delta, reason, created_at';

  static CreditPack pack(Map<String, dynamic> json) => CreditPack(
    id: json['id'] as String,
    uses: json['uses'] as int,
    pricePiastres: json['price_piastres'] as int,
  );

  static PaymentAccount account(Map<String, dynamic> json) => PaymentAccount(
    method: enumFromWire(TopupMethod.values, json['method']),
    account: json['account'] as String,
    holderName: json['holder_name'] as String,
  );

  static Topup topup(Map<String, dynamic> json) => Topup(
    id: json['id'] as String,
    uses: json['uses'] as int,
    amountPiastres: json['amount_piastres'] as int,
    method: enumFromWire(TopupMethod.values, json['method']),
    status: enumFromWire(TopupStatus.values, json['status']),
    rejectReason: json['reject_reason'] as String?,
    createdAt: timeFromWire(json['created_at']),
  );

  static LedgerEntry ledgerEntry(Map<String, dynamic> json) => LedgerEntry(
    id: json['id'] as int,
    delta: json['delta'] as int,
    reason: enumFromWire(LedgerReason.values, json['reason']),
    createdAt: timeFromWire(json['created_at']),
  );
}
