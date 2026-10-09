import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/overview_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/domain/repositories/overview_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOverviewRepository implements OverviewRepository {
  SupabaseOverviewRepository(SupabaseClient client) : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<AdminOverview>> fetchOverview(OverviewPeriod period) =>
      _rpc.call('admin_overview', {
        'p_period': toWire(period),
      }, OverviewModels.overview);

  @override
  Future<Result<AreaCoverageReport>> fetchAreas(
    OverviewPeriod period, {
    required int limit,
    required int offset,
  }) => _rpc.call('admin_list_areas', {
    'p_period': toWire(period),
    'p_limit': limit,
    'p_offset': offset,
  }, OverviewModels.areas);
}
