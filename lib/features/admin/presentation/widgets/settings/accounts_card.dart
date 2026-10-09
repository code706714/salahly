import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/text_limit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_form_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/settings_card.dart';
import 'package:salahly/features/balance/presentation/balance_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Where people send money, per method: the number or address, whose it
/// is, and whether it is shown on the top-up screen.
class AccountsCard extends StatelessWidget {
  const AccountsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<SettingsFormCubit>().state;
    return SettingsCard(
      title: l10n.adminSettingsAccountsTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final original in state.original.paymentAccounts) ...[
            _AccountTile(
              original: original,
              account: state.accounts[original.method]!,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            l10n.adminSettingsAccountsNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({required this.original, required this.account});

  /// The longest a number, an address or a name may be.
  static const _maxLength = 100;

  /// What was loaded, which the fields start from.
  final PaymentAccountSetting original;

  /// What is typed now.
  final PaymentAccountSetting account;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final form = context.read<SettingsFormCubit>();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: colors.border, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    topupMethodLabel(l10n, original.method),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Tooltip(
                  message: l10n.adminSettingsAccountOn,
                  child: Switch(
                    value: account.isActive,
                    onChanged: (isActive) => form.accountChanged(
                      original.method,
                      isActive: isActive,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: original.account,
              inputFormatters: const [CodePointLimit(_maxLength)],
              onChanged: (text) =>
                  form.accountChanged(original.method, account: text),
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.adminSettingsAccountNumber,
                errorText: account.account.trim().isEmpty
                    ? l10n.adminErrorInvalid
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              initialValue: original.holderName,
              inputFormatters: const [CodePointLimit(_maxLength)],
              onChanged: (text) =>
                  form.accountChanged(original.method, holderName: text),
              decoration: InputDecoration(
                isDense: true,
                labelText: l10n.adminSettingsAccountHolder,
                errorText: account.holderName.trim().isEmpty
                    ? l10n.adminErrorInvalid
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
