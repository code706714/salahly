import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/domain/repositories/settings_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_form_cubit.dart';

/// Saves what the admin changed in the settings. Prices, free uses and
/// payment accounts need a sign in from the last 15 minutes; without one
/// the failure is a `RecentLoginRequiredFailure` and `retry` saves again
/// after the admin signs in anew.
class SettingsActionsCubit extends ActionCubit {
  SettingsActionsCubit(this._repository);

  final SettingsRepository _repository;

  /// Saves every change in [form], one after the other, and stops at the
  /// first the server refuses. Saving again after that sends the same
  /// values, so what already went through is not changed twice.
  Future<void> save(SettingsFormState form) => perform(() async {
    if (form.freeUsesChanged) {
      final result = await _repository.updateFreeUses(
        consumerFreeRequests: form.consumerFreeRequests,
        technicianFreeJobs: form.technicianFreeJobs,
        verifiedTechnicianTarget: form.verifiedTechnicianTarget,
      );
      if (result is Err) return result;
    }
    for (final pack in form.changedPacks) {
      final result = await _repository.saveCreditPack(pack);
      if (result is Err) return result;
    }
    for (final account in form.changedAccounts) {
      final result = await _repository.updatePaymentAccount(account);
      if (result is Err) return result;
    }
    return const Ok(null);
  }, outcome: AdminOutcome.settingsSaved);

  Future<void> addPack(CreditPackDraft pack) => perform(
    () => _repository.saveCreditPack(pack),
    outcome: AdminOutcome.packAdded,
  );

  Future<void> saveArea(AreaDraft area) => perform(
    () => _repository.saveArea(area),
    outcome: AdminOutcome.areaSaved,
  );

  Future<void> setAreaOpen(String areaId, {required bool isOpen}) => perform(
    () => _repository.setAreaOpen(areaId, isOpen: isOpen),
    outcome: AdminOutcome.settingsSaved,
  );
}
