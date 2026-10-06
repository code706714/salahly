import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/text/text_limit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/widgets/field_label.dart';
import 'package:salahly/features/onboarding/presentation/widgets/photo_slot.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class TechnicianProfileStep extends StatelessWidget {
  const TechnicianProfileStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<TechnicianOnboardingCubit>();
    final state = context.watch<TechnicianOnboardingCubit>().state;
    final showErrors = state.showErrors;
    final missingPhoto = showErrors && state.avatarPath == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text(
          l10n.techProfileTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Row(
          children: [
            PhotoSlot(
              label: l10n.techPhoto,
              icon: Icons.photo_camera_outlined,
              path: state.avatarPath,
              purpose: PhotoPurpose.avatar,
              onPicked: cubit.avatarPicked,
              radius: AppRadii.pill,
              width: 88,
              height: 88,
              hasError: missingPhoto,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                missingPhoto ? l10n.techPhotoRequired : l10n.techPhotoHint,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: missingPhoto ? colors.danger : colors.inkMuted,
                ),
              ),
            ),
          ],
        ),
        FieldLabel(l10n.nameLabel),
        TextFormField(
          initialValue: state.fullName,
          onChanged: cubit.nameChanged,
          inputFormatters: const [
            CodePointLimit(maxNameLength),
          ],
          autofillHints: const [AutofillHints.name],
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            errorText: showErrors && !state.isNameValid
                ? l10n.nameInvalid
                : null,
          ),
        ),
        FieldLabel(l10n.techShopLabel),
        TextFormField(
          initialValue: state.shopName,
          onChanged: cubit.shopNameChanged,
          inputFormatters: const [
            CodePointLimit(maxNameLength),
          ],
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            hintText: l10n.techShopHint,
            errorText: showErrors && !state.isShopNameValid
                ? l10n.techShopInvalid
                : null,
          ),
        ),
        FieldLabel(l10n.techYearsLabel),
        TextFormField(
          initialValue: state.yearsText,
          onChanged: cubit.yearsChanged,
          keyboardType: TextInputType.number,
          inputFormatters: digitInputFormatters(maxLength: 2),
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            errorText: showErrors && state.yearsExperience == null
                ? l10n.techYearsInvalid
                : null,
          ),
        ),
      ],
    );
  }
}
