import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/activity_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/admin_activity.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/repositories/activity_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseActivityRepository implements ActivityRepository {
  SupabaseActivityRepository(SupabaseClient client) : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<MoneySummary>> fetchMoney(OverviewPeriod period) =>
      _rpc.call('admin_money_summary', {
        'p_period': toWire(period),
      }, ActivityModels.money);

  @override
  Future<Result<ActivityReport>> fetchTechnicians(OverviewPeriod period) =>
      _rpc.call('admin_technician_activity', {
        'p_period': toWire(period),
        'p_limit': 100,
      }, ActivityModels.activity);
}
