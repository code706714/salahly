import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/widgets/area_picker_sheet.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The label and details lengths the server takes.
const _labelMaxLength = 30;
const _detailsMinLength = 3;
const _detailsMaxLength = 300;

/// Opens the form for a new address, or for editing [address]. [onSave]
/// saves what was entered and returns why it failed, if it did; the sheet
/// closes once saved and keeps the entries after a failure.
Future<void> showAddressForm(
  BuildContext context, {
  required Future<Failure?> Function(ConsumerAddressDraft draft) onSave,
  ConsumerAddress? address,
}) {
  final areas = context.read<AreasCubit>();
  // Retries the area list if it couldn't be fetched at start.
  unawaited(areas.load());
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BlocProvider.value(
      value: areas,
      child: _AddressForm(address: address, onSave: onSave),
    ),
  );
}

class _AddressForm extends StatefulWidget {
  const _AddressForm({required this.address, required this.onSave});

  final ConsumerAddress? address;
  final Future<Failure?> Function(ConsumerAddressDraft draft) onSave;

  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  late final _label = TextEditingController(text: widget.address?.label);
  late final _details = TextEditingController(text: widget.address?.details);
  late String? _areaId = widget.address?.areaId;
  bool _showsErrors = false;
  bool _saving = false;
  Failure? _failure;

  @override
  void dispose() {
    _label.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickArea() async {
    final area = await showAreaPicker(
      context,
      areas: context.read<AreasCubit>().state.areas,
    );
    if (area != null) setState(() => _areaId = area.id);
  }

  Future<void> _save() async {
    final label = _label.text.trim();
    final details = _details.text.trim();
    final areaId = _areaId;
    if (label.isEmpty || details.length < _detailsMinLength || areaId == null) {
      setState(() => _showsErrors = true);
      return;
    }
    setState(() {
      _saving = true;
      _failure = null;
    });
    final failure = await widget.onSave(
      ConsumerAddressDraft(label: label, areaId: areaId, details: details),
    );
    if (!mounted) return;
    if (failure == null) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final textTheme = Theme.of(context).textTheme;
    final area = context.select<AreasCubit, ServiceArea?>(
      (cubit) =>
          cubit.state.areas.where((area) => area.id == _areaId).firstOrNull,
    );
    final failure = _failure;
    final labelMissing = _showsErrors && _label.text.trim().isEmpty;
    final detailsMissing =
        _showsErrors && _details.text.trim().length < _detailsMinLength;
    final areaMissing = _showsErrors && _areaId == null;

    Widget fieldLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: textTheme.labelLarge),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              widget.address == null
                  ? l10n.addressesNew
                  : l10n.addressesEdit(honorific),
              style: textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 16),
          fieldLabel(l10n.addressesLabel),
          TextField(
            controller: _label,
            maxLength: _labelMaxLength,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => null,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: l10n.addressesLabelHint,
              hintStyle: TextStyle(fontSize: 16, color: colors.inkMuted),
              errorText: labelMissing
                  ? l10n.addressesLabelRequired(honorific)
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          fieldLabel(l10n.addressesArea),
          InkWell(
            onTap: _pickArea,
            borderRadius: BorderRadius.circular(AppRadii.md),
            child: InputDecorator(
              isEmpty: area == null,
              decoration: InputDecoration(
                hintText: l10n.addressesAreaPick(honorific),
                hintStyle: TextStyle(fontSize: 16, color: colors.inkMuted),
                errorText: areaMissing
                    ? l10n.addressesAreaRequired(honorific)
                    : null,
                suffixIcon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: colors.inkMuted,
                ),
              ),
              child: Text(
                area?.name ?? '',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          fieldLabel(l10n.addressesDetails),
          TextField(
            controller: _details,
            maxLength: _detailsMaxLength,
            minLines: 2,
            maxLines: 4,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => setState(() {}),
            buildCounter:
                (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) => currentLength >= _detailsMaxLength - 50
                ? Text('$currentLength/$maxLength')
                : null,
            style: const TextStyle(fontSize: 16, height: 1.6),
            decoration: InputDecoration(
              hintText: l10n.addressesDetailsHint,
              hintStyle: TextStyle(fontSize: 16, color: colors.inkMuted),
              errorText: detailsMissing
                  ? l10n.addressesDetailsRequired(honorific)
                  : null,
            ),
          ),
          if (failure != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                consumerFailureMessage(l10n, failure, honorific: honorific),
                style: TextStyle(fontSize: 14, color: colors.danger),
              ),
            ),
          ],
          const SizedBox(height: 16),
          BusyFilledButton(
            label: l10n.addressesSave(honorific),
            isBusy: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
