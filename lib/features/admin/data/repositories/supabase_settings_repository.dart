import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/admin/data/models/settings_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/domain/repositories/settings_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseSettingsRepository implements SettingsRepository {
  SupabaseSettingsRepository(SupabaseClient client) : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<AdminSettings>> fetchSettings() =>
      _rpc.call('admin_get_settings', const {}, SettingsModels.settings);

  @override
  Future<Result<void>> updateFreeUses({
    int? consumerFreeRequests,
    int? technicianFreeJobs,
    int? verifiedTechnicianTarget,
  }) => _rpc.run('admin_update_settings', {
    'p_consumer_free_requests': consumerFreeRequests,
    'p_technician_free_jobs': technicianFreeJobs,
    'p_verified_technician_target': verifiedTechnicianTarget,
  });

  @override
  Future<Result<void>> saveCreditPack(CreditPackDraft pack) =>
      _rpc.run('admin_save_credit_pack', {
        'p_id': pack.id,
        'p_role': toWire(pack.role),
        'p_uses': pack.uses,
        'p_price_piastres': pack.pricePiastres,
        'p_is_active': pack.isActive,
        'p_sort_order': pack.sortOrder,
      });

  @override
  Future<Result<void>> updatePaymentAccount(PaymentAccountSetting account) =>
      _rpc.run('admin_update_payment_account', {
        'p_method': toWire(account.method),
        'p_account': account.account,
        'p_holder_name': account.holderName,
        'p_is_active': account.isActive,
      });

  @override
  Future<Result<void>> saveArea(AreaDraft area) =>
      _rpc.run('admin_save_service_area', {
        'p_id': area.id,
        'p_name_ar': area.name,
        'p_city_ar': area.city,
        'p_center_lat': area.centerLat,
        'p_center_lng': area.centerLng,
        'p_is_open': area.isOpen,
      });

  @override
  Future<Result<void>> setAreaOpen(String areaId, {required bool isOpen}) =>
      _rpc.run('admin_set_area_open', {
        'p_area_id': areaId,
        'p_is_open': isOpen,
      });
}
