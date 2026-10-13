import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/router/app_routes.dart' show AppRoutes;
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/features/calls/domain/services/call_engine.dart';
import 'package:salahly/features/calls/presentation/cubit/call_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A voice call, made or taken, the same screen on both sides.
class CallPage extends StatelessWidget {
  const CallPage({
    required this.requestId,
    required this.technicianId,
    required this.name,
    this.callId,
    super.key,
  });

  /// The page for the query [AppRoutes.call] builds.
  factory CallPage.fromQuery(Uri uri) => CallPage(
    requestId: uri.queryParameters['request'] ?? '',
    technicianId: uri.queryParameters['technician'] ?? '',
    name: uri.queryParameters['name'] ?? '',
    callId: uri.queryParameters['call'],
  );

  final String requestId;
  final String technicianId;
  final String name;

  /// The ringing call to take; null to make a new one.
  final String? callId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = CallCubit(
          calls: context.read(),
          engine: context.read<CallEngineFactory>()(),
          requestId: requestId,
          technicianId: technicianId,
          incomingCallId: callId,
        );
        unawaited(cubit.start());
        return cubit;
      },
      child: CallView(name: name),
    );
  }
}

class CallView extends StatelessWidget {
  const CallView({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.watch<CallCubit>();
    final state = cubit.state;
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              InitialsAvatar(name: name, size: 112),
              const SizedBox(height: 20),
              Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: colors.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _status(l10n, state),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: colors.inkMuted,
                ),
              ),
              const Spacer(flex: 3),
              if (state.phase != CallPhase.ended)
                Text(
                  l10n.callSafetyNote,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colors.inkMuted,
                  ),
                ),
              const SizedBox(height: 24),
              _Controls(state: state, cubit: cubit),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static String _status(AppLocalizations l10n, CallState state) =>
      switch (state.phase) {
        CallPhase.starting => l10n.callStarting,
        CallPhase.ringing => l10n.callRinging,
        CallPhase.incoming => l10n.callIncoming,
        CallPhase.connecting => l10n.callConnecting,
        CallPhase.connected => _clock(state.seconds),
        CallPhase.ended => switch (state.end!) {
          CallEnd.hungUp => l10n.callEndedHungUp,
          CallEnd.remoteEnded => l10n.callEndedRemote,
          CallEnd.declined => l10n.callEndedDeclined,
          CallEnd.missed => l10n.callEndedMissed,
          CallEnd.busy => l10n.callEndedBusy,
          CallEnd.alreadyCalling => l10n.callEndedAlreadyCalling,
          CallEnd.unavailable => l10n.callEndedUnavailable,
          CallEnd.microphone => l10n.callEndedMicrophone,
          CallEnd.failed => l10n.callEndedFailed,
        },
      };

  static String _clock(int seconds) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(seconds ~/ 60)}:${two(seconds % 60)}';
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.state, required this.cubit});

  final CallState state;
  final CallCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    switch (state.phase) {
      case CallPhase.ended:
        return SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.maybePop(context),
            child: Text(l10n.callDone),
          ),
        );
      case CallPhase.incoming:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: Icons.call_end_rounded,
              label: l10n.callDecline,
              background: colors.danger,
              foreground: colors.onPrimary,
              onPressed: cubit.decline,
            ),
            _RoundButton(
              icon: Icons.call_rounded,
              label: l10n.callAccept,
              background: colors.success,
              foreground: colors.onPrimary,
              onPressed: cubit.accept,
            ),
          ],
        );
      case CallPhase.starting ||
          CallPhase.ringing ||
          CallPhase.connecting ||
          CallPhase.connected:
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RoundButton(
              icon: state.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: state.muted ? l10n.callUnmute : l10n.callMute,
              background: state.muted ? colors.ink : colors.inkSoft,
              foreground: state.muted ? colors.background : colors.ink,
              onPressed: cubit.toggleMute,
            ),
            _RoundButton(
              icon: Icons.call_end_rounded,
              label: l10n.callHangUp,
              background: colors.danger,
              foreground: colors.onPrimary,
              onPressed: cubit.hangUp,
            ),
            _RoundButton(
              icon: Icons.volume_up_rounded,
              label: l10n.callSpeaker,
              background: state.speaker ? colors.ink : colors.inkSoft,
              foreground: state.speaker ? colors.background : colors.ink,
              onPressed: cubit.toggleSpeaker,
            ),
          ],
        );
    }
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: background,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: 68,
                height: 68,
                child: Icon(icon, size: 30, color: foreground),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: context.appColors.inkMuted,
          ),
        ),
      ],
    );
  }
}
