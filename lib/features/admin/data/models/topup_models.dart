import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

/// Maps what `admin_list_topups` returns.
abstract final class TopupModels {
  static PagedResult<TopupReview> topups(Map<String, dynamic> json) =>
      PagedResult(
        total: intOf(json['total']),
        items: [for (final item in listFromWire(json['items'])) _topup(item)],
      );

  static TopupReview _topup(Map<String, dynamic> json) => TopupReview(
    id: json['id'] as String,
    userId: json['user_id'] as String?,
    name: json['name'] as String?,
    accountPhone: json['account_phone'] as String?,
    role: enumFromWire(UserRole.values, json['role']),
    uses: intOf(json['uses']),
    amountPiastres: intOf(json['amount_piastres']),
    method: enumFromWire(TopupMethod.values, json['method']),
    senderAccount: json['sender_account'] as String,
    screenshotPath: json['screenshot_path'] as String,
    status: enumFromWire(TopupStatus.values, json['status']),
    rejectReason: json['reject_reason'] as String?,
    createdAt: timeFromWire(json['created_at']),
    reviewedAt: optionalTimeFromWire(json['reviewed_at']),
  );
}
