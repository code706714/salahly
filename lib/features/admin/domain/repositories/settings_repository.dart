import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';

abstract interface class SettingsRepository {
  Future<Result<AdminSettings>> fetchSettings();

  /// Changes only the values that are not null. What people already hold
  /// does not change, only what new accounts get.
  Future<Result<void>> updateFreeUses({
    int? consumerFreeRequests,
    int? technicianFreeJobs,
    int? verifiedTechnicianTarget,
  });

  /// Adds a pack, or changes the one [CreditPackDraft.id] names.
  Future<Result<void>> saveCreditPack(CreditPackDraft pack);

  Future<Result<void>> updatePaymentAccount(PaymentAccountSetting account);

  /// Adds an area, or changes the one with the same id.
  Future<Result<void>> saveArea(AreaDraft area);

  Future<Result<void>> setAreaOpen(String areaId, {required bool isOpen});
}
