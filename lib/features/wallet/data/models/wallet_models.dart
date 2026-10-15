import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

/// Maps the wallet function's JSON to domain entities.
abstract final class WalletModels {
  static Wallet wallet(Map<String, dynamic> json) => Wallet(
    balancePiastres: json['balance_piastres'] as int,
    minWithdrawalPiastres: json['min_withdrawal_piastres'] as int,
    lastDestination: json['last_destination'] == null
        ? null
        : _destination(json['last_destination'] as Map<String, dynamic>),
    entries: listFromWire(json['entries']).map(_entry).toList(),
    withdrawals: listFromWire(json['withdrawals']).map(_withdrawal).toList(),
  );

  static WithdrawalDestination _destination(Map<String, dynamic> json) =>
      WithdrawalDestination(
        method: enumFromWire(TopupMethod.values, json['method']),
        account: json['account'] as String,
        holderName: json['holder_name'] as String,
      );

  static WalletEntry _entry(Map<String, dynamic> json) => WalletEntry(
    id: json['id'] as int,
    kind: enumFromWire(WalletEntryKind.values, json['kind']),
    amountPiastres: json['amount_piastres'] as int,
    requestCode: json['request_code'] as String?,
    createdAt: timeFromWire(json['created_at']),
  );

  static Withdrawal _withdrawal(Map<String, dynamic> json) => Withdrawal(
    id: json['id'] as String,
    amountPiastres: json['amount_piastres'] as int,
    method: enumFromWire(TopupMethod.values, json['method']),
    account: json['account'] as String,
    status: enumFromWire(WithdrawalStatus.values, json['status']),
    reference: json['reference'] as String?,
    rejectReason: json['reject_reason'] as String?,
    createdAt: timeFromWire(json['created_at']),
  );
}
