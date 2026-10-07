import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';

part 'settings_form_state.dart';

/// The settings as the admin edits them, before anything is saved. Typed
/// numbers that are not valid are kept as null, which blocks saving.
class SettingsFormCubit extends Cubit<SettingsFormState> {
  SettingsFormCubit(AdminSettings settings)
    : super(SettingsFormState.from(settings));

  /// The most free uses a new account can get.
  static const maxFreeUses = 20;

  void consumerFreeRequestsChanged(int value) => emit(
    state.copyWith(consumerFreeRequests: value.clamp(0, maxFreeUses)),
  );

  void technicianFreeJobsChanged(int value) => emit(
    state.copyWith(technicianFreeJobs: value.clamp(0, maxFreeUses)),
  );

  void targetChanged(String text) => emit(
    state.copyWith(verifiedTechnicianTarget: () => _targetOf(text)),
  );

  void packPriceChanged(String packId, String text) => emit(
    state.copyWith(packPrices: {...state.packPrices, packId: _priceOf(text)}),
  );

  void packActiveChanged(String packId, {required bool isActive}) => emit(
    state.copyWith(packActive: {...state.packActive, packId: isActive}),
  );

  void accountChanged(
    TopupMethod method, {
    String? account,
    String? holderName,
    bool? isActive,
  }) {
    final current = state.accounts[method]!;
    emit(
      state.copyWith(
        accounts: {
          ...state.accounts,
          method: PaymentAccountSetting(
            method: method,
            account: account ?? current.account,
            holderName: holderName ?? current.holderName,
            isActive: isActive ?? current.isActive,
          ),
        },
      ),
    );
  }

  static int? _targetOf(String text) {
    final value = parseWholeNumber(text);
    return value != null && value >= 1 && value <= 100000 ? value : null;
  }

  static int? _priceOf(String text) {
    final piastres = parsePounds(text);
    return piastres != null &&
            piastres >= SettingsFormState.minPricePiastres &&
            piastres <= SettingsFormState.maxPricePiastres
        ? piastres
        : null;
  }
}
