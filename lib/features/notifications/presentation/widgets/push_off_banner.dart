import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/features/notifications/presentation/cubit/push_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Tells a person whose push is off what they miss, and how to turn it on:
/// offers, arrival notices and calls only show while the app is open.
class PushOffBanner extends StatelessWidget {
  const PushOffBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<PushCubit, PushStatus>(
      (cubit) => cubit.state.status,
    );
    if (status != PushStatus.denied && status != PushStatus.deferred) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.pushOffBanner,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => unawaited(
                status == PushStatus.denied
                    ? context.read<ExternalApps>().openSettings()
                    : context.read<PushCubit>().allow(),
              ),
              child: Text(
                status == PushStatus.denied
                    ? l10n.pushOffOpenSettings
                    : l10n.pushOffTurnOn,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
