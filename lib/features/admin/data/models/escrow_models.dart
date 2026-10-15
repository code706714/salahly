import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/escrow_review.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';

/// Maps what `admin_list_escrows` returns.
abstract final class AdminEscrowModels {
  static PagedResult<EscrowReview> escrows(Map<String, dynamic> json) =>
      PagedResult(
        total: intOf(json['total']),
        items: [for (final item in listFromWire(json['items'])) _escrow(item)],
      );

  static EscrowReview _escrow(Map<String, dynamic> json) => EscrowReview(
    id: json['id'] as String,
    requestCode: json['request_code'] as String,
    status: enumFromWire(EscrowStatus.values, json['status']),
    amountPiastres: intOf(json['amount_piastres']),
    method: json['method'] == null
        ? null
        : enumFromWire(TopupMethod.values, json['method']),
    senderAccount: json['sender_account'] as String?,
    screenshotPath: json['screenshot_path'] as String?,
    onlineMethod: json['online_method'] as String?,
    createdAt: timeFromWire(json['created_at']),
    consumerName: json['consumer_name'] as String?,
    consumerPhone: json['consumer_phone'] as String?,
    technicianName: json['technician_name'] as String?,
    technicianPhone: json['technician_phone'] as String?,
    payoutMethod: json['payout_method'] == null
        ? null
        : enumFromWire(TopupMethod.values, json['payout_method']),
    payoutAccount: json['payout_account'] as String?,
    payoutHolder: json['payout_holder'] as String?,
    payoutReference: json['payout_reference'] as String?,
    refundReference: json['refund_reference'] as String?,
    rejectReason: json['reject_reason'] as String?,
    disputeReason: json['dispute_reason'] as String?,
    resolutionNote: json['resolution_note'] as String?,
  );
}
