import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';

import '../../helpers/balance_fixtures.dart';

/// The consumer's view of a request with a 350 EGP guarantee.
EscrowInfo testEscrowInfo({
  bool canSecure = false,
  bool canConfirm = false,
  bool canDispute = false,
  Escrow? escrow,
}) => EscrowInfo(
  amountPiastres: 35000,
  canSecure: canSecure,
  canConfirm: canConfirm,
  canDispute: canDispute,
  accounts: paymentAccounts,
  escrow: escrow,
);

Escrow testEscrow(
  EscrowStatus status, {
  String? rejectReason,
  DateTime? autoReleaseAt,
}) => Escrow(
  status: status,
  method: TopupMethod.instapay,
  createdAt: DateTime(2026, 10, 13, 10),
  rejectReason: rejectReason,
  autoReleaseAt: autoReleaseAt,
);
