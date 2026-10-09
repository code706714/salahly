import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';

/// Maps `my_notifications` JSON to domain entities.
abstract final class NotificationModel {
  /// The notification, or null for a kind this version doesn't know (a
  /// newer server): it is skipped rather than failing the list.
  static AppNotification? fromJson(Map<String, dynamic> json) {
    final kind = NotificationKind.values
        .where((kind) => toWire(kind) == json['kind'])
        .firstOrNull;
    if (kind == null) return null;
    return AppNotification(
      id: json['id'] as String,
      kind: kind,
      createdAt: timeFromWire(json['created_at']),
      readAt: optionalTimeFromWire(json['read_at']),
      requestId: json['request_id'] as String?,
      topupId: json['topup_id'] as String?,
      categoryId: json['category_id'] as String?,
      issue: _optional(RequestIssue.values, json['issue']),
      areaId: json['area_id'] as String?,
      day: json['preferred_on'] == null
          ? null
          : dateFromWire(json['preferred_on']),
      window: _optional(RequestWindow.values, json['time_window']),
      pricePiastres: json['price_piastres'] as int?,
      arriveAt: optionalTimeFromWire(json['arrive_at']),
      technicianName: json['technician_name'] as String?,
      consumerName: json['consumer_name'] as String?,
      consumerHonorific: _optional(
        Honorific.values,
        json['consumer_honorific'],
      ),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      topupUses: json['topup_uses'] as int?,
    );
  }

  static T? _optional<T extends Enum>(List<T> values, Object? wire) =>
      wire == null ? null : enumFromWire(values, wire);
}
