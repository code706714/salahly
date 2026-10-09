import 'package:flutter/material.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_form_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks for the size and the price of a new pack of [role]. Resolves to the
/// pack, or null when the admin cancels.
Future<CreditPackDraft?> showAddPackDialog(
  BuildContext context, {
  required UserRole role,
}) {
  return showDialog<CreditPackDraft>(
    context: context,
    builder: (context) => _AddPackDialog(role: role),
  );
}

class _AddPackDialog extends StatefulWidget {
  const _AddPackDialog({required this.role});

  final UserRole role;

  @override
  State<_AddPackDialog> createState() => _AddPackDialogState();
}

class _AddPackDialogState extends State<_AddPackDialog> {
  static const _maxUses = 1000;

  final _uses = TextEditingController();
  final _price = TextEditingController();

  @override
  void dispose() {
    _uses.dispose();
    _price.dispose();
    super.dispose();
  }

  int? get _usesValue {
    final uses = parseWholeNumber(_uses.text);
    return uses != null && uses >= 1 && uses <= _maxUses ? uses : null;
  }

  int? get _priceValue {
    final price = parsePounds(_price.text);
    return price != null &&
            price >= SettingsFormState.minPricePiastres &&
            price <= SettingsFormState.maxPricePiastres
        ? price
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final uses = _usesValue;
    final price = _priceValue;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      title: Text(
        l10n.adminSettingsAddPackTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 380, maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _uses,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: digitInputFormatters(maxLength: 4),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.adminSettingsPackUses,
                errorText: _uses.text.isNotEmpty && uses == null
                    ? l10n.adminSettingsPackUsesInvalid
                    : null,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _price,
              keyboardType: TextInputType.number,
              inputFormatters: digitInputFormatters(maxLength: 7),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l10n.adminSettingsPackPriceField,
                suffixText: l10n.currencyEgp,
                errorText: _price.text.isNotEmpty && price == null
                    ? l10n.adminSettingsPackPriceInvalid
                    : null,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminCancel),
        ),
        TextButton(
          onPressed: uses == null || price == null
              ? null
              : () => Navigator.of(context).pop(
                  CreditPackDraft(
                    role: widget.role,
                    uses: uses,
                    pricePiastres: price,
                  ),
                ),
          child: Text(l10n.adminSettingsPackAdd),
        ),
      ],
    );
  }
}
