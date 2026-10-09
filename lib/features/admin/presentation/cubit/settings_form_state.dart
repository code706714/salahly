part of 'settings_form_cubit.dart';

final class SettingsFormState extends Equatable {
  const SettingsFormState({
    required this.original,
    required this.consumerFreeRequests,
    required this.technicianFreeJobs,
    required this.verifiedTechnicianTarget,
    required this.packPrices,
    required this.packActive,
    required this.accounts,
  });

  factory SettingsFormState.from(AdminSettings settings) {
    return SettingsFormState(
      original: settings,
      consumerFreeRequests: settings.consumerFreeRequests,
      technicianFreeJobs: settings.technicianFreeJobs,
      verifiedTechnicianTarget: settings.verifiedTechnicianTarget,
      packPrices: {
        for (final pack in settings.packs) pack.id: pack.pricePiastres,
      },
      packActive: {for (final pack in settings.packs) pack.id: pack.isActive},
      accounts: {
        for (final account in settings.paymentAccounts) account.method: account,
      },
    );
  }

  /// The prices the server accepts: 1 to 1,000,000 pounds.
  static const minPricePiastres = 100;
  static const maxPricePiastres = 100000000;

  /// What was loaded, to find what changed.
  final AdminSettings original;
  final int consumerFreeRequests;
  final int technicianFreeJobs;

  /// Null while what was typed is not a valid number.
  final int? verifiedTechnicianTarget;

  /// By pack id, in piastres; null while what was typed is not valid.
  final Map<String, int?> packPrices;
  final Map<String, bool> packActive;
  final Map<TopupMethod, PaymentAccountSetting> accounts;

  bool get freeUsesChanged =>
      consumerFreeRequests != original.consumerFreeRequests ||
      technicianFreeJobs != original.technicianFreeJobs ||
      verifiedTechnicianTarget != original.verifiedTechnicianTarget;

  /// The packs whose price or availability changed, those being switched on
  /// first so a role never has nothing on sale in between.
  List<CreditPackDraft> get changedPacks {
    final changed = [
      for (final pack in original.packs)
        if (packPrices[pack.id] != pack.pricePiastres ||
            packActive[pack.id] != pack.isActive)
          CreditPackDraft(
            id: pack.id,
            role: pack.role,
            uses: pack.uses,
            pricePiastres: packPrices[pack.id] ?? pack.pricePiastres,
            sortOrder: pack.sortOrder,
            isActive: packActive[pack.id]!,
          ),
    ];
    return changed..sort((a, b) => _switchedOnFirst(a.isActive, b.isActive));
  }

  /// The accounts that changed, those being switched on first.
  List<PaymentAccountSetting> get changedAccounts {
    final changed = [
      for (final account in original.paymentAccounts)
        if (accounts[account.method] != account) accounts[account.method]!,
    ];
    return changed..sort((a, b) => _switchedOnFirst(a.isActive, b.isActive));
  }

  bool get hasChanges =>
      freeUsesChanged || changedPacks.isNotEmpty || changedAccounts.isNotEmpty;

  /// Whether everything typed is valid, so it can be saved.
  bool get isValid =>
      verifiedTechnicianTarget != null &&
      packPrices.values.every((price) => price != null) &&
      accounts.values.every(
        (account) =>
            account.account.trim().isNotEmpty &&
            account.holderName.trim().isNotEmpty,
      );

  static int _switchedOnFirst(bool a, bool b) => a == b ? 0 : (a ? -1 : 1);

  SettingsFormState copyWith({
    int? consumerFreeRequests,
    int? technicianFreeJobs,
    int? Function()? verifiedTechnicianTarget,
    Map<String, int?>? packPrices,
    Map<String, bool>? packActive,
    Map<TopupMethod, PaymentAccountSetting>? accounts,
  }) {
    return SettingsFormState(
      original: original,
      consumerFreeRequests: consumerFreeRequests ?? this.consumerFreeRequests,
      technicianFreeJobs: technicianFreeJobs ?? this.technicianFreeJobs,
      verifiedTechnicianTarget: verifiedTechnicianTarget != null
          ? verifiedTechnicianTarget()
          : this.verifiedTechnicianTarget,
      packPrices: packPrices ?? this.packPrices,
      packActive: packActive ?? this.packActive,
      accounts: accounts ?? this.accounts,
    );
  }

  @override
  List<Object?> get props => [
    original,
    consumerFreeRequests,
    technicianFreeJobs,
    verifiedTechnicianTarget,
    packPrices,
    packActive,
    accounts,
  ];
}
