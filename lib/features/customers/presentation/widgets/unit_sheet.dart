import 'dart:math';

import 'package:flutter/material.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/text/normalize.dart';
import 'package:salahly/core/text/text_limit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/customers/presentation/customer_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What the unit sheet closed with.
sealed class UnitSheetResult {
  const UnitSheetResult();
}

/// Save the unit as [draft].
final class UnitSaved extends UnitSheetResult {
  const UnitSaved(this.draft);

  final CustomerUnitDraft draft;
}

/// Delete the unit being edited.
final class UnitDeleteRequested extends UnitSheetResult {
  const UnitDeleteRequested();
}

/// Asks for a new unit's details, or changes [unit]'s. Resolves to null
/// when dismissed.
Future<UnitSheetResult?> showUnitSheet(
  BuildContext context, {
  required DateTime today,
  CustomerUnit? unit,
}) {
  return showModalBottomSheet<UnitSheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => UnitSheet(unit: unit, today: today),
  );
}

/// The unit form inside [showUnitSheet].
class UnitSheet extends StatefulWidget {
  const UnitSheet({required this.today, this.unit, super.key});

  /// Local midnight of the current day.
  final DateTime today;
  final CustomerUnit? unit;

  /// The capacities offered, in horsepower.
  static const capacities = [1.0, 1.5, 2.25, 3.0, 4.0, 5.0];

  /// The earliest installation year accepted.
  static const firstYear = 1980;

  @override
  State<UnitSheet> createState() => _UnitSheetState();
}

class _UnitSheetState extends State<UnitSheet> {
  late final _brand = TextEditingController(text: widget.unit?.brand);
  late final _room = TextEditingController(text: widget.unit?.room);
  late final _year = TextEditingController(
    text: widget.unit?.installedYear?.toString(),
  );
  late double? _capacity = widget.unit?.capacityHp;
  late DateTime? _nextService = widget.unit?.nextServiceOn;
  bool _showErrors = false;

  @override
  void dispose() {
    _brand.dispose();
    _room.dispose();
    _year.dispose();
    super.dispose();
  }

  /// The year typed, null when empty; invalid years fail [_isYearValid].
  int? get _installedYear => parseWholeNumber(_year.text);

  bool get _isYearValid {
    if (digitsOnly(_year.text).isEmpty) return true;
    final year = _installedYear;
    return year != null &&
        year >= UnitSheet.firstYear &&
        year <= widget.today.year;
  }

  void _save() {
    if (!_isYearValid) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.of(context).pop(
      UnitSaved(
        CustomerUnitDraft(
          brand: normalizeText(_brand.text),
          capacityHp: _capacity,
          room: normalizeText(_room.text),
          installedYear: _installedYear,
          nextServiceOn: _nextService,
        ),
      ),
    );
  }

  Future<void> _pickDay() async {
    final today = widget.today;
    final current = _nextService;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? _addMonths(today, 6),
      firstDate: current != null && current.isBefore(today) ? current : today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (picked != null && mounted) setState(() => _nextService = picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final today = widget.today;
    final capacity = _capacity;
    final capacities = {
      ...UnitSheet.capacities,
      ?capacity,
    }.toList()..sort();
    final inSixMonths = _addMonths(today, 6);
    final inAYear = _addMonths(today, 12);
    final nextService = _nextService;
    final isPreset = nextService == inSixMonths || nextService == inAYear;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 12,
          children: [
            Text(
              widget.unit == null ? l10n.unitAddTitle : l10n.unitEditTitle,
              style: textTheme.titleMedium,
            ),
            Text(l10n.unitBrand, style: textTheme.labelLarge),
            TextField(
              controller: _brand,
              inputFormatters: const [CodePointLimit(40)],
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(hintText: l10n.unitBrandHint),
            ),
            Text(l10n.unitCapacity, style: textTheme.labelLarge),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hp in capacities)
                  ChoiceChipButton(
                    label: l10n.unitHp(formatHp(hp)),
                    selected: hp == capacity,
                    onTap: () =>
                        setState(() => _capacity = hp == capacity ? null : hp),
                    minHeight: 48,
                  ),
              ],
            ),
            Text(l10n.unitRoom, style: textTheme.labelLarge),
            TextField(
              controller: _room,
              inputFormatters: const [CodePointLimit(40)],
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(hintText: l10n.unitRoomHint),
            ),
            Text(l10n.unitInstalledYear, style: textTheme.labelLarge),
            TextField(
              controller: _year,
              keyboardType: TextInputType.number,
              inputFormatters: digitInputFormatters(maxLength: 4),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                errorText: _showErrors && !_isYearValid
                    ? l10n.unitInstalledYearInvalid(
                        UnitSheet.firstYear,
                        today.year,
                      )
                    : null,
              ),
            ),
            Text(l10n.unitNextService, style: textTheme.labelLarge),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChipButton(
                  label: l10n.unitNoNextService,
                  selected: nextService == null,
                  onTap: () => setState(() => _nextService = null),
                  minHeight: 48,
                ),
                ChoiceChipButton(
                  label: l10n.unitInSixMonths,
                  selected: nextService == inSixMonths,
                  onTap: () => setState(() => _nextService = inSixMonths),
                  minHeight: 48,
                ),
                ChoiceChipButton(
                  label: l10n.unitInAYear,
                  selected: nextService == inAYear,
                  onTap: () => setState(() => _nextService = inAYear),
                  minHeight: 48,
                ),
                ChoiceChipButton(
                  label: nextService == null || isPreset
                      ? l10n.unitPickDay
                      : serviceDayLabel(l10n, nextService, today: today),
                  icon: Icons.calendar_today_outlined,
                  selected: nextService != null && !isPreset,
                  onTap: _pickDay,
                  minHeight: 48,
                ),
              ],
            ),
            const SizedBox(height: 4),
            FilledButton(onPressed: _save, child: Text(l10n.unitSave)),
            if (widget.unit != null)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: colors.danger),
                onPressed: () =>
                    Navigator.of(context).pop(const UnitDeleteRequested()),
                child: Text(l10n.unitDelete),
              ),
          ],
        ),
      ),
    );
  }
}

/// [months] after [day], on the same day of the month or the month's last
/// day when it is shorter: 31 August + 6 months is 28 February.
DateTime _addMonths(DateTime day, int months) {
  final month = DateTime(day.year, day.month + months);
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(month.year, month.month, min(day.day, lastDay));
}
