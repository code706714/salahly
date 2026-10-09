import 'package:flutter/material.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/catalog/presentation/category_icon.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The services of every open trade, a card per trade: tick the ones the
/// technician does and write the starting price of each.
class ServicePricePicker extends StatelessWidget {
  const ServicePricePicker({
    required this.categories,
    required this.selectedIds,
    required this.priceTexts,
    required this.invalidIds,
    required this.onToggle,
    required this.onPriceChanged,
    super.key,
  });

  /// The open trades; others are left out.
  final List<ServiceCategory> categories;
  final Set<String> selectedIds;

  /// The typed price of each service, in pounds.
  final Map<String, String> priceTexts;

  /// Ticked services whose price can't be used, shown in red.
  final Set<String> invalidIds;
  final ValueChanged<CatalogService> onToggle;
  final void Function(String serviceId, String value) onPriceChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        for (final category in categories)
          if (category.isActive && category.services.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                Row(
                  spacing: 8,
                  children: [
                    Icon(
                      categoryIcon(category.id),
                      size: 22,
                      color: colors.primary,
                    ),
                    Text(
                      category.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: colors.border, width: 1.5),
                  ),
                  child: Column(
                    children: [
                      for (final service in category.services) ...[
                        if (service != category.services.first) const Divider(),
                        _ServiceRow(
                          service: service,
                          selected: selectedIds.contains(service.id),
                          priceText: priceTexts[service.id] ?? '',
                          invalid: invalidIds.contains(service.id),
                          onToggle: () => onToggle(service),
                          onPriceChanged: (value) =>
                              onPriceChanged(service.id, value),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.selected,
    required this.priceText,
    required this.invalid,
    required this.onToggle,
    required this.onPriceChanged,
  });

  final CatalogService service;
  final bool selected;
  final String priceText;
  final bool invalid;
  final VoidCallback onToggle;
  final ValueChanged<String> onPriceChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 14, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              checked: selected,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      _CheckBox(checked: selected),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          service.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: selected ? colors.ink : colors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Opacity(
            opacity: selected ? 1 : 0.4,
            child: Container(
              width: 116,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(
                  color: invalid ? colors.danger : colors.fieldBorder,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    l10n.priceFrom,
                    style: TextStyle(fontSize: 13, color: colors.inkMuted),
                  ),
                  Expanded(
                    child: TextFormField(
                      // Rebuilt on toggle to show the pre-filled price.
                      key: ValueKey('${service.id}-$selected'),
                      initialValue: priceText,
                      enabled: selected,
                      onChanged: onPriceChanged,
                      keyboardType: TextInputType.number,
                      inputFormatters: digitInputFormatters(maxLength: 7),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: InputDecoration(
                        hintText: '${service.suggestedPricePiastres ~/ 100}',
                        hintStyle: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.inkMuted,
                        ),
                        isDense: true,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  Text(
                    l10n.currencyEgp,
                    style: TextStyle(fontSize: 13, color: colors.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: checked ? colors.primary : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: checked ? colors.primary : colors.dashedBorder,
          width: 2,
        ),
      ),
      child: checked
          ? Icon(Icons.check_rounded, size: 18, color: colors.onPrimary)
          : null,
    );
  }
}
