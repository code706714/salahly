import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Where to send the money, with a button that copies the account.
class TransferAccountCard extends StatelessWidget {
  const TransferAccountCard({
    required this.account,
    required this.honorific,
    super.key,
  });

  final PaymentAccount account;
  final String honorific;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final copied = AppLocalizations.of(context).buyUsesCopied;
    await Clipboard.setData(ClipboardData(text: account.account));
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(copied)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final label = switch (account.method) {
      TopupMethod.instapay => l10n.buyUsesAccountInstapay,
      TopupMethod.wallet => l10n.buyUsesAccountWallet,
    };
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: colors.inkMuted),
                ),
                Text(
                  account.account,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  l10n.buyUsesHolder(account.holderName),
                  style: TextStyle(fontSize: 13, color: colors.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => _copy(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              backgroundColor: Colors.white,
              foregroundColor: colors.ink,
              side: BorderSide(color: colors.fieldBorder, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              textStyle: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: Text(l10n.buyUsesCopy(honorific)),
          ),
        ],
      ),
    );
  }
}
