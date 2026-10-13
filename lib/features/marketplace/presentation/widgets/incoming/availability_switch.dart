import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/marketplace/presentation/cubit/availability_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "متاح دلوقتي": the technician says they are free, so urgent requests near
/// them reach them for the next few hours.
class AvailabilitySwitch extends StatelessWidget {
  const AvailabilitySwitch({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = AvailabilityCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const _SwitchCard(),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<AvailabilityCubit>();
    final state = context.watch<AvailabilityCubit>().state;
    final until = state.until;
    final isOn = state.isOnAt(DateTime.now());
    return BlocListener<AvailabilityCubit, AvailabilityState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.availabilityFailed))),
      child: AppCard(
        radius: AppRadii.lg,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 24,
              color: isOn ? colors.brass : colors.inkMuted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.availabilityTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isOn && until != null
                        ? l10n.availabilityOn(timeLabel(l10n, until.toLocal()))
                        : l10n.availabilityOff,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: isOn,
              onChanged: state.isBusy
                  ? null
                  : (on) => unawaited(cubit.toggle(on: on)),
            ),
          ],
        ),
      ),
    );
  }
}
