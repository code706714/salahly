import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_form_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// How many uses a new account gets for free, with buttons for one more
/// and one less. What people already hold does not change.
class FreeUsesStepper extends StatelessWidget {
  const FreeUsesStepper({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton.outlined(
          tooltip: l10n.adminSettingsLess,
          visualDensity: VisualDensity.compact,
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_rounded),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: colors.ink,
            ),
          ),
        ),
        IconButton.outlined(
          tooltip: l10n.adminSettingsMore,
          visualDensity: VisualDensity.compact,
          onPressed: value < SettingsFormCubit.maxFreeUses
              ? () => onChanged(value + 1)
              : null,
          icon: const Icon(Icons.add_rounded),
        ),
      ],
    );
  }
}

/// The number of verified technicians the launch waits for.
class TargetField extends StatelessWidget {
  const TargetField({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<SettingsFormCubit>();
    final state = context.watch<SettingsFormCubit>().state;
    return TextFormField(
      initialValue: '${state.original.verifiedTechnicianTarget}',
      keyboardType: TextInputType.number,
      inputFormatters: digitInputFormatters(maxLength: 6),
      onChanged: cubit.targetChanged,
      decoration: InputDecoration(
        isDense: true,
        labelText: l10n.adminSettingsTarget,
        errorText: state.verifiedTechnicianTarget == null
            ? l10n.adminSettingsTargetInvalid
            : null,
        errorMaxLines: 2,
      ),
    );
  }
}
