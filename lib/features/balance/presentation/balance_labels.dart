import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

String topupMethodLabel(AppLocalizations l10n, TopupMethod method) =>
    switch (method) {
      TopupMethod.instapay => l10n.buyUsesMethodInstapay,
      TopupMethod.wallet => l10n.buyUsesMethodWallet,
    };

String topupStatusLabel(AppLocalizations l10n, TopupStatus status) =>
    switch (status) {
      TopupStatus.pending => l10n.balanceStatusPending,
      TopupStatus.approved => l10n.balanceStatusApproved,
      TopupStatus.rejected => l10n.balanceStatusRejected,
    };

PillTone topupStatusTone(TopupStatus status) => switch (status) {
  TopupStatus.pending => PillTone.waiting,
  TopupStatus.approved => PillTone.success,
  TopupStatus.rejected => PillTone.danger,
};

/// What moved the balance, in the words of [role]'s side.
String ledgerReasonLabel(
  AppLocalizations l10n,
  LedgerReason reason, {
  required UserRole role,
}) => switch (reason) {
  LedgerReason.requestSent => switch (role) {
    UserRole.consumer => l10n.balanceLedgerRequestSent,
    UserRole.technician => l10n.balanceLedgerOfferPicked,
  },
  LedgerReason.requestRefunded => l10n.balanceLedgerRefunded,
  LedgerReason.topup => l10n.balanceLedgerTopup,
  LedgerReason.adminAdjustment => l10n.balanceLedgerAdjustment,
};
