import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

import 'mocks.dart';

const consumerPacks = [
  CreditPack(id: 'pack-1', uses: 1, pricePiastres: 2000),
  CreditPack(id: 'pack-5', uses: 5, pricePiastres: 8000),
];

const technicianPacks = [
  CreditPack(id: 'pack-t1', uses: 1, pricePiastres: 3000),
  CreditPack(id: 'pack-t10', uses: 10, pricePiastres: 25000),
];

const paymentAccounts = [
  PaymentAccount(
    method: TopupMethod.instapay,
    account: 'salahly@instapay',
    holderName: 'شركة صلحلي',
  ),
  PaymentAccount(
    method: TopupMethod.wallet,
    account: '01000000000',
    holderName: 'شركة صلحلي',
  ),
];

Topup testTopup({
  String id = 'topup-1',
  int uses = 5,
  int amountPiastres = 8000,
  TopupMethod method = TopupMethod.instapay,
  TopupStatus status = TopupStatus.pending,
  String? rejectReason,
  DateTime? createdAt,
}) => Topup(
  id: id,
  uses: uses,
  amountPiastres: amountPiastres,
  method: method,
  status: status,
  rejectReason: rejectReason,
  createdAt: createdAt ?? DateTime(2026, 10, 4, 14, 30),
);

LedgerEntry testLedgerEntry({
  int id = 1,
  int delta = -1,
  LedgerReason reason = LedgerReason.requestSent,
  DateTime? createdAt,
}) => LedgerEntry(
  id: id,
  delta: delta,
  reason: reason,
  createdAt: createdAt ?? DateTime(2026, 10, 3, 9),
);

/// Packs and accounts on sale, and no transfers or movements yet.
void stubBalance(MockBalanceRepository balance, {bool consumer = true}) {
  when(() => balance.fetchPacks(any())).thenAnswer(
    (_) async => Ok(consumer ? consumerPacks : technicianPacks),
  );
  when(
    balance.fetchPaymentAccounts,
  ).thenAnswer((_) async => const Ok(paymentAccounts));
  when(() => balance.fetchTopups(any())).thenAnswer((_) async => const Ok([]));
  when(() => balance.fetchLedger(any())).thenAnswer((_) async => const Ok([]));
}
