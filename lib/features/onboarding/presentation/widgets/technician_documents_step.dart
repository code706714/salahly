import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/onboarding/presentation/cubit/technician_onboarding_cubit.dart';
import 'package:salahly/features/onboarding/presentation/widgets/field_label.dart';
import 'package:salahly/features/onboarding/presentation/widgets/photo_slot.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class TechnicianDocumentsStep extends StatelessWidget {
  const TechnicianDocumentsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final state = context.watch<TechnicianOnboardingCubit>().state;

    Widget slot(DocumentSlot slot, String label, IconData icon) {
      return PhotoSlot(
        label: label,
        icon: icon,
        path: state.documents[slot],
        purpose: PhotoPurpose.document,
        onPicked: (path) => context
            .read<TechnicianOnboardingCubit>()
            .documentPicked(slot, path),
        radius: AppRadii.md,
        height: 112,
        hasError: state.showErrors && state.documents[slot] == null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        Text(l10n.techDocsTitle, style: Theme.of(context).textTheme.titleLarge),
        Text(
          l10n.techDocsBody,
          style: TextStyle(fontSize: 15, height: 1.7, color: colors.inkMuted),
        ),
        Row(
          spacing: 10,
          children: [
            Expanded(
              child: slot(
                DocumentSlot.idFront,
                l10n.techIdFront,
                Icons.badge_outlined,
              ),
            ),
            Expanded(
              child: slot(
                DocumentSlot.idBack,
                l10n.techIdBack,
                Icons.credit_card_outlined,
              ),
            ),
          ],
        ),
        slot(
          DocumentSlot.selfieWithId,
          l10n.techSelfieWithId,
          Icons.person_outline_rounded,
        ),
        if (state.showErrors && !state.isDocumentsValid)
          FieldError(l10n.techDocsRequired),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: colors.inkSoft,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(Icons.shield_outlined, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.techDocsPrivacy,
                  style: const TextStyle(fontSize: 14, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
