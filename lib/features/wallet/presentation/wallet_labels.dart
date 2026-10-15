import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What a move of money in the wallet says: "فلوس شغلانة SL-1042".
String walletEntryLabel(AppLocalizations l10n, WalletEntry entry) =>
    switch (entry.kind) {
      WalletEntryKind.escrow => l10n.walletEntryEscrow(entry.requestCode ?? ''),
      WalletEntryKind.withdrawal => l10n.walletEntryWithdrawal,
      WalletEntryKind.withdrawalRefund => l10n.walletEntryWithdrawalRefund,
    };

/// Where a withdrawal stands, in words.
String withdrawalStatusLabel(AppLocalizations l10n, Withdrawal withdrawal) =>
    switch (withdrawal.status) {
      WithdrawalStatus.requested => l10n.walletWithdrawalRequested,
      WithdrawalStatus.paid => l10n.walletWithdrawalPaid(
        withdrawal.reference ?? '',
      ),
      WithdrawalStatus.rejected => l10n.walletWithdrawalRejected(
        withdrawal.rejectReason ?? '',
      ),
    };

PillTone withdrawalStatusTone(WithdrawalStatus status) => switch (status) {
  WithdrawalStatus.requested => PillTone.waiting,
  WithdrawalStatus.paid => PillTone.success,
  WithdrawalStatus.rejected => PillTone.danger,
};
