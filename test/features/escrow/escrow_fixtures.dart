import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';
import 'package:salahly/features/payments/domain/entities/payment.dart';

/// The consumer's view of a request with a 350 EGP guarantee.
EscrowInfo testEscrowInfo({
  bool canSecure = false,
  bool canConfirm = false,
  bool canDispute = false,
  PaymentStatus? paymentStatus,
  Escrow? escrow,
}) => EscrowInfo(
  amountPiastres: 35000,
  canSecure: canSecure,
  canConfirm: canConfirm,
  canDispute: canDispute,
  paymentStatus: paymentStatus,
  escrow: escrow,
);

Escrow testEscrow(
  EscrowStatus status, {
  TopupMethod? method = TopupMethod.instapay,
  String? rejectReason,
  DateTime? autoReleaseAt,
}) => Escrow(
  status: status,
  method: method,
  createdAt: DateTime(2026, 10, 13, 10),
  rejectReason: rejectReason,
  autoReleaseAt: autoReleaseAt,
);
