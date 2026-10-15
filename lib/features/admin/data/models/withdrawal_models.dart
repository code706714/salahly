import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/withdrawal_review.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

/// Maps what `admin_list_withdrawals` returns.
abstract final class AdminWithdrawalModels {
  static PagedResult<WithdrawalReview> withdrawals(Map<String, dynamic> json) =>
      PagedResult(
        total: intOf(json['total']),
        items: [
          for (final item in listFromWire(json['items'])) _withdrawal(item),
        ],
      );

  static WithdrawalReview _withdrawal(Map<String, dynamic> json) =>
      WithdrawalReview(
        id: json['id'] as String,
        status: enumFromWire(WithdrawalStatus.values, json['status']),
        amountPiastres: intOf(json['amount_piastres']),
        method: enumFromWire(TopupMethod.values, json['method']),
        account: json['account'] as String,
        holderName: json['holder_name'] as String,
        createdAt: timeFromWire(json['created_at']),
        technicianName: json['technician_name'] as String?,
        technicianPhone: json['technician_phone'] as String?,
        reference: json['reference'] as String?,
        rejectReason: json['reject_reason'] as String?,
        processedAt: optionalTimeFromWire(json['processed_at']),
      );
}
