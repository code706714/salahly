import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';

/// Maps the escrow functions' JSON to domain entities.
abstract final class EscrowModels {
  static EscrowInfo info(Map<String, dynamic> json) => EscrowInfo(
    amountPiastres: json['amount_piastres'] as int,
    canSecure: json['can_secure'] as bool,
    canConfirm: json['can_confirm'] as bool,
    canDispute: json['can_dispute'] as bool,
    paymentStatus: json['payment'] == null
        ? null
        : enumFromWire(
            PaymentStatus.values,
            (json['payment'] as Map<String, dynamic>)['status'],
          ),
    escrow: json['escrow'] == null
        ? null
        : _escrow(json['escrow'] as Map<String, dynamic>),
  );

  static Escrow _escrow(Map<String, dynamic> json) => Escrow(
    status: enumFromWire(EscrowStatus.values, json['status']),
    method: json['method'] == null
        ? null
        : enumFromWire(TopupMethod.values, json['method']),
    rejectReason: json['reject_reason'] as String?,
    createdAt: timeFromWire(json['created_at']),
    autoReleaseAt: optionalTimeFromWire(json['auto_release_at']),
  );

  static TechnicianEscrow technicianEscrow(Map<String, dynamic> json) =>
      TechnicianEscrow(
        status: enumFromWire(EscrowStatus.values, json['status']),
        amountPiastres: json['amount_piastres'] as int,
      );

  static PayoutAccount payoutAccount(Map<String, dynamic> json) =>
      PayoutAccount(
        method: enumFromWire(TopupMethod.values, json['method']),
        account: json['account'] as String,
        holderName: json['holder_name'] as String,
      );
}
