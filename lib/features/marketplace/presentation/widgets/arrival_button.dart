import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/features/marketplace/presentation/cubit/arrival_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "قربت أوصل": the technician tells the consumer he is almost there. Shown
/// on a platform job once it is confirmed and until the work starts.
class ArrivalButton extends StatelessWidget {
  const ArrivalButton({
    required this.jobId,
    required this.isOffline,
    super.key,
  });

  final String jobId;

  /// The phone has no internet: the button says so, before it is tapped.
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = ArrivalCubit(requests: context.read(), jobId: jobId);
        unawaited(cubit.load());
        return cubit;
      },
      child: _ArrivalView(isOffline: isOffline),
    );
  }
}

class _ArrivalView extends StatelessWidget {
  const _ArrivalView({required this.isOffline});

  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return BlocConsumer<ArrivalCubit, ArrivalState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(arrivalFailureMessage(l10n, state.failure!))),
        ),
      builder: (context, state) {
        final style = OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: colors.ink,
          disabledForegroundColor: colors.success,
          backgroundColor: colors.surface,
          disabledBackgroundColor: colors.successSoft,
          side: BorderSide(color: colors.fieldBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          textStyle: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        );
        final hint = state.isSent
            ? null
            : isOffline
            ? l10n.arrivalOffline
            : l10n.arrivalHint;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OutlinedButton.icon(
              onPressed: state.isSent || state.isSending
                  ? null
                  : context.read<ArrivalCubit>().send,
              style: style,
              icon: state.isSending
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.inkMuted,
                      ),
                    )
                  : Icon(
                      state.isSent
                          ? Icons.check_rounded
                          : Icons.directions_walk_rounded,
                      size: 22,
                    ),
              label: Text(state.isSent ? l10n.arrivalSent : l10n.arrivalButton),
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isOffline ? colors.warning : colors.inkMuted,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
