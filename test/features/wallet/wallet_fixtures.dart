import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

final walletNow = DateTime(2026, 10, 15, 12);

Wallet testWallet({
  int balance = 85000,
  int min = 5000,
  WithdrawalDestination? last,
  List<WalletEntry>? entries,
  List<Withdrawal>? withdrawals,
}) => Wallet(
  balancePiastres: balance,
  minWithdrawalPiastres: min,
  lastDestination: last,
  entries:
      entries ??
      [
        WalletEntry(
          id: 2,
          kind: WalletEntryKind.escrow,
          amountPiastres: 35000,
          createdAt: walletNow,
          requestCode: 'R-1048',
        ),
        WalletEntry(
          id: 1,
          kind: WalletEntryKind.withdrawal,
          amountPiastres: -10000,
          createdAt: walletNow,
        ),
      ],
  withdrawals: withdrawals ?? const [],
);

const testDestination = WithdrawalDestination(
  method: TopupMethod.wallet,
  account: '01005551234',
  holderName: 'محمود سعيد',
);

Withdrawal testWithdrawal({
  WithdrawalStatus status = WithdrawalStatus.requested,
  String? reference,
  String? rejectReason,
}) => Withdrawal(
  id: 'w-1',
  amountPiastres: 20000,
  method: TopupMethod.wallet,
  account: '01005551234',
  status: status,
  createdAt: walletNow,
  reference: reference,
  rejectReason: rejectReason,
);
