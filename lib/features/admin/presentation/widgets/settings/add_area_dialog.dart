import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/text/text_limit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Asks for a new area. Resolves to it, or null when the admin cancels.
///
/// Saving an area under an id that exists changes that area, so [existingIds]
/// are refused here: this is for adding.
Future<AreaDraft?> showAddAreaDialog(
  BuildContext context, {
  required Set<String> existingIds,
}) {
  return showDialog<AreaDraft>(
    context: context,
    builder: (context) => _AddAreaDialog(existingIds: existingIds),
  );
}

class _AddAreaDialog extends StatefulWidget {
  const _AddAreaDialog({required this.existingIds});

  final Set<String> existingIds;

  @override
  State<_AddAreaDialog> createState() => _AddAreaDialogState();
}

class _AddAreaDialogState extends State<_AddAreaDialog> {
  static final _idPattern = RegExp(r'^[a-z][a-z0-9_]{1,47}$');

  final _id = TextEditingController();
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _lat = TextEditingController();
  final _lng = TextEditingController();

  @override
  void dispose() {
    _id.dispose();
    _name.dispose();
    _city.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  bool get _idValid => _idPattern.hasMatch(_id.text);
  bool get _idTaken => widget.existingIds.contains(_id.text);

  static bool _validText(String text) {
    final length = text.trim().runes.length;
    return length >= 2 && length <= 40;
  }

  static double? _coordinate(
    String text, {
    required double min,
    required double max,
  }) {
    final value = double.tryParse(normalizeDigits(text.trim()));
    return value != null && value >= min && value <= max ? value : null;
  }

  double? get _latValue => _coordinate(_lat.text, min: 22, max: 32);
  double? get _lngValue => _coordinate(_lng.text, min: 24, max: 37);

  bool get _isValid =>
      _idValid &&
      !_idTaken &&
      _validText(_name.text) &&
      _validText(_city.text) &&
      _latValue != null &&
      _lngValue != null;

  void _submit() => Navigator.of(context).pop(
    AreaDraft(
      id: _id.text,
      name: _name.text.trim(),
      city: _city.text.trim(),
      centerLat: _latValue!,
      centerLng: _lngValue!,
    ),
  );

  InputDecoration _decoration(String label, {String? error}) =>
      InputDecoration(labelText: label, errorText: error);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    const coordinateFormatters = [CodePointLimit(12)];
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      title: Text(
        l10n.adminSettingsAddAreaTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 420, maxWidth: 460),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _id,
                autofocus: true,
                textDirection: TextDirection.ltr,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-z0-9_]')),
                  const CodePointLimit(48),
                ],
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  l10n.adminSettingsAreaId,
                  error: _id.text.isEmpty
                      ? null
                      : _idTaken
                      ? l10n.adminErrorDuplicate
                      : _idValid
                      ? null
                      : l10n.adminSettingsAreaInvalid,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                inputFormatters: const [CodePointLimit(40)],
                onChanged: (_) => setState(() {}),
                decoration: _decoration(l10n.adminSettingsAreaName),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _city,
                inputFormatters: const [CodePointLimit(40)],
                onChanged: (_) => setState(() {}),
                decoration: _decoration(l10n.adminSettingsAreaCity),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                inputFormatters: coordinateFormatters,
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  l10n.adminSettingsAreaLat,
                  error: _lat.text.isNotEmpty && _latValue == null
                      ? l10n.adminSettingsAreaInvalid
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _lng,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                inputFormatters: coordinateFormatters,
                onChanged: (_) => setState(() {}),
                decoration: _decoration(
                  l10n.adminSettingsAreaLng,
                  error: _lng.text.isNotEmpty && _lngValue == null
                      ? l10n.adminSettingsAreaInvalid
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.adminCancel),
        ),
        TextButton(
          onPressed: _isValid ? _submit : null,
          child: Text(l10n.adminSettingsAreaAdd),
        ),
      ],
    );
  }
}
