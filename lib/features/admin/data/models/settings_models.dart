import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/data/models/json_values.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';

/// Maps what `admin_get_settings` returns.
abstract final class SettingsModels {
  static AdminSettings settings(Map<String, dynamic> json) => AdminSettings(
    consumerFreeRequests: intOf(json['consumer_free_requests']),
    technicianFreeJobs: intOf(json['technician_free_jobs']),
    verifiedTechnicianTarget: intOf(json['verified_technician_target']),
    packs: [
      for (final pack in listFromWire(json['packs']))
        CreditPackSetting(
          id: pack['id'] as String,
          role: enumFromWire(UserRole.values, pack['role']),
          uses: intOf(pack['uses']),
          pricePiastres: intOf(pack['price_piastres']),
          sortOrder: intOf(pack['sort_order']),
          isActive: pack['is_active'] as bool,
        ),
    ],
    paymentAccounts: [
      for (final account in listFromWire(json['payment_accounts']))
        PaymentAccountSetting(
          method: enumFromWire(TopupMethod.values, account['method']),
          account: account['account'] as String,
          holderName: account['holder_name'] as String,
          isActive: account['is_active'] as bool,
        ),
    ],
  );
}
