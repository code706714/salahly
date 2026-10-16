import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_activity.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';

// Like every admin repository, these answer with a failure instead of
// throwing.

abstract interface class ActivityRepository {
  /// The money of today, this week (from Saturday) or this month.
  Future<Result<MoneySummary>> fetchMoney(OverviewPeriod period);

  /// What technicians did in the same spans.
  Future<Result<ActivityReport>> fetchTechnicians(OverviewPeriod period);
}
