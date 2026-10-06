import 'package:flutter/material.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Where a request stands for the technician, as a pill: their offer, the
/// consumer's pick, or why it closed. Nothing while it waits for an offer.
class StandingPill extends StatelessWidget {
  const StandingPill({
    required this.request,
    required this.standing,
    super.key,
  });

  final IncomingRequest request;
  final IncomingStanding standing;

  @override
  Widget build(BuildContext context) {
    final label = standingLabel(
      AppLocalizations.of(context),
      request,
      standing,
    );
    if (label == null) return const SizedBox.shrink();
    final (tone, icon) = switch (standing) {
      IncomingStanding.offerSent => (PillTone.waiting, Icons.schedule_rounded),
      IncomingStanding.chosen => (PillTone.success, Icons.check_rounded),
      _ => (PillTone.danger, null),
    };
    return StatusPill(label: label, tone: tone, icon: icon);
  }
}
