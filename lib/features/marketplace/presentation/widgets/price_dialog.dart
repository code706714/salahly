import 'package:flutter/material.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks for a price in whole pounds between [range]'s ends. Resolves to the
/// price in piastres, or null if dismissed.
Future<int?> showPriceDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String confirm,
  required ({int min, int max}) range,
}) {
  return showDialog<int>(
    context: context,
    builder: (context) => _PriceDialog(
      title: title,
      body: body,
      confirm: confirm,
      range: range,
    ),
  );
}

class _PriceDialog extends StatefulWidget {
  const _PriceDialog({
    required this.title,
    required this.body,
    required this.confirm,
    required this.range,
  });

  final String title;
  final String body;
  final String confirm;
  final ({int min, int max}) range;

  @override
  State<_PriceDialog> createState() => _PriceDialogState();
}

class _PriceDialogState extends State<_PriceDialog> {
  final _price = TextEditingController();

  /// Whether to say the price is wrong; not before the first try.
  bool _showsError = false;

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  /// The typed price, when it is in range.
  int? get _valid {
    final price = parsePounds(_price.text);
    return price != null &&
            price >= widget.range.min &&
            price <= widget.range.max
        ? price
        : null;
  }

  void _submit() {
    final price = _valid;
    if (price == null) {
      setState(() => _showsError = true);
      return;
    }
    Navigator.of(context).pop(price);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final range = widget.range;
    final bounds = range.min == range.max
        ? l10n.pounds(formatPounds(range.min))
        : l10n.priceRange(formatPounds(range.min), formatPounds(range.max));
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      title: Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.body,
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: digitInputFormatters(maxLength: 7),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() => _showsError = false),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              suffixText: l10n.currencyEgp,
              helperText: bounds,
              errorText: _showsError ? bounds : null,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.priceDialogCancel),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(foregroundColor: colors.primary),
          child: Text(widget.confirm),
        ),
      ],
    );
  }
}
