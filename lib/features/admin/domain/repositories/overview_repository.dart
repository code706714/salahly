import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';

// Every admin repository answers with a failure instead of throwing. Besides
// the failures any call can end in, each can end in `AdminRequiredFailure`
// when the account is not an admin. The calls that move money or change
// prices can also end in `RecentLoginRequiredFailure`: the admin has to sign
// in again, then repeat the call.

abstract interface class OverviewRepository {
  Future<Result<AdminOverview>> fetchOverview(OverviewPeriod period);

  Future<Result<AreaCoverageReport>> fetchAreas(
    OverviewPeriod period, {
    required int limit,
    required int offset,
  });
}
