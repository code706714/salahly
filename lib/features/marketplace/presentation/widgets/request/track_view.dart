import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';
import 'package:salahly/core/widgets/square_icon_button.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/request_follow_up.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/complaint_link.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/request_unavailable_view.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The picked technician on the way and at work, step by step.
class TrackView extends StatelessWidget {
  const TrackView({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    final offer = details.chosenOffer;
    if (offer == null) return const RequestUnavailableView(missing: false);
    final l10n = AppLocalizations.of(context);
    final name = firstNameOf(offer.technician.name);
    final title = switch (details.stage) {
      RequestStage.confirmed when details.technicianArrivingAt != null =>
        l10n.trackTitleArriving(name),
      RequestStage.confirmed => l10n.trackConfirmed(name),
      RequestStage.started => l10n.trackTitleStarted(name),
      _ => l10n.trackTitleChosen(name),
    };
    return Scaffold(
      appBar: DetailHeader(
        title: context.watchRequestName(details.categoryId, details.issue),
      ),
      body: PullToRefresh(
        onRefresh: () => context.read<RequestCubit>().refresh(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _TechnicianCard(details: details, offer: offer),
            const SizedBox(height: 16),
            _Steps(details: details, offer: offer),
            const SizedBox(height: 16),
            _Summary(details: details, offer: offer),
            const SizedBox(height: 20),
            _Footer(details: details, technician: name),
          ],
        ),
      ),
    );
  }
}

class _TechnicianCard extends StatelessWidget {
  const _TechnicianCard({required this.details, required this.offer});

  final RequestDetails details;
  final RequestOffer offer;

  Future<void> _sendHello(
    BuildContext context, {
    required PhoneNumber phone,
    required String request,
  }) {
    final consumer = switch (context.read<SessionCubit>().state) {
      SessionReady(:final profile) => firstNameOf(profile.fullName),
      _ => '',
    };
    final text = AppLocalizations.of(context).trackWhatsAppMessage(
      context.readHonorific(),
      firstNameOf(offer.technician.name),
      consumer,
      request,
    );
    return context.sendOnWhatsApp(text, to: phone);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final technician = offer.technician;
    final first = firstNameOf(technician.name);
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.category(details.categoryId)?.name,
    );
    final request = context.watchRequestName(details.categoryId, details.issue);
    final phone = PhoneNumber.tryParse(details.technicianPhone ?? '');
    final rating = technician.rating;
    final about = [
      if (rating != null) rating.toStringAsFixed(1),
      if (category != null)
        technician.verified
            ? l10n.trackVerified(category)
            : l10n.trackTechnician(category),
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.push(AppRoutes.technicianProfile(technician.id)),
      child: Row(
        children: [
          DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.brass, width: 2),
            ),
            child: InitialsAvatar(name: technician.name, size: 52),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  technician.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
                if (about.isNotEmpty)
                  Row(
                    children: [
                      if (rating != null) ...[
                        Icon(Icons.star_rounded, size: 16, color: colors.brass),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          about,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: colors.inkMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          if (phone != null) ...[
            const SizedBox(width: 12),
            SquareIconButton(
              icon: Icons.call_outlined,
              tooltip: l10n.trackCall(context.watchHonorific(), first),
              background: colors.inkSoft,
              onPressed: () => context.dial(phone),
            ),
            const SizedBox(width: 12),
            SquareIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: l10n.trackWhatsApp(first),
              background: colors.whatsapp,
              foreground: colors.onWhatsapp,
              onPressed: () =>
                  _sendHello(context, phone: phone, request: request),
            ),
          ],
        ],
      ),
    );
  }
}

enum _StepState { done, current, ahead }

typedef _Step = ({
  String title,
  String? note,
  _StepState state,
  IconData icon,
});

/// From sending the request to the invoice; the steps done are checked
/// and the one under way is highlighted.
class _Steps extends StatelessWidget {
  const _Steps({required this.details, required this.offer});

  final RequestDetails details;
  final RequestOffer offer;

  List<_Step> _steps(AppLocalizations l10n, String honorific) {
    final job = details.job;
    final name = firstNameOf(offer.technician.name);
    final stage = details.stage;
    final confirmed =
        stage == RequestStage.confirmed || stage == RequestStage.started;
    final started = stage == RequestStage.started;
    String? at(DateTime? time) => time == null ? null : momentLabel(l10n, time);
    final arrivingAt = details.technicianArrivingAt;
    return [
      (
        title: l10n.trackStepSent,
        note: at(details.createdAt),
        state: _StepState.done,
        icon: Icons.check_rounded,
      ),
      (
        title: l10n.trackStepChosen(
          honorific,
          name,
          formatPounds(offer.pricePiastres),
        ),
        note: at(details.chosenAt),
        state: _StepState.done,
        icon: Icons.check_rounded,
      ),
      if (confirmed)
        (
          title: l10n.trackConfirmed(name),
          note: at(job?.scheduledAt),
          state: _StepState.done,
          icon: Icons.check_rounded,
        )
      else
        (
          title: l10n.trackConfirming(name),
          note: null,
          state: _StepState.current,
          icon: Icons.schedule_rounded,
        ),
      (
        title: l10n.trackStepStarted,
        note: started
            ? at(job?.startedAt)
            : confirmed && arrivingAt != null
            ? l10n.trackArrivingNote(momentLabel(l10n, arrivingAt))
            : null,
        state: started
            ? _StepState.done
            : confirmed
            ? _StepState.current
            : _StepState.ahead,
        icon: started ? Icons.check_rounded : Icons.schedule_rounded,
      ),
      (
        title: l10n.trackStepFinished(honorific),
        note: null,
        state: started ? _StepState.current : _StepState.ahead,
        icon: Icons.handyman_outlined,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final steps = _steps(
      AppLocalizations.of(context),
      context.watchHonorific(),
    );
    return AppCard(
      child: Column(
        children: [
          for (final (index, step) in steps.indexed)
            _StepRow(
              step: step,
              lineColor: switch (steps.elementAtOrNull(index + 1)?.state) {
                null => null,
                _StepState.done => colors.successBright,
                _StepState.current => colors.primary,
                _StepState.ahead => colors.border,
              },
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.lineColor});

  final _Step step;

  /// The line down to the next step; null for the last one.
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final lineColor = this.lineColor;
    final note = step.note;
    final dot = switch (step.state) {
      _StepState.done => BoxDecoration(
        color: colors.successBright,
        shape: BoxShape.circle,
      ),
      _StepState.current => BoxDecoration(
        color: colors.primary,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: colors.primarySoft, spreadRadius: 5)],
      ),
      _StepState.ahead => BoxDecoration(
        color: colors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: colors.fieldBorder, width: 2),
      ),
    };
    return Semantics(
      selected: step.state == _StepState.current,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: dot,
                  child: step.state == _StepState.ahead
                      ? null
                      : Icon(step.icon, size: 18, color: colors.onPrimary),
                ),
                if (lineColor != null)
                  Expanded(
                    child: Container(
                      width: 2,
                      constraints: const BoxConstraints(minHeight: 22),
                      margin: const EdgeInsets.only(top: 4),
                      color: lineColor,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: lineColor == null ? 0 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.5,
                        fontWeight: step.state == _StepState.current
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: switch (step.state) {
                          _StepState.done => colors.ink,
                          _StepState.current => colors.primaryPressed,
                          _StepState.ahead => colors.inkMuted,
                        },
                      ),
                    ),
                    if (note != null)
                      Text(
                        note,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: colors.inkMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The price, how to pay and where.
class _Summary extends StatelessWidget {
  const _Summary({required this.details, required this.offer});

  final RequestDetails details;
  final RequestOffer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final job = details.job;
    // Once a new price was approved, the job's total is what was agreed.
    final changed =
        job != null && details.priceChangeAnswer == QuoteStatus.accepted;
    final value = TextStyle(
      fontSize: 15,
      height: 1.6,
      fontWeight: FontWeight.w700,
      color: colors.ink,
    );
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          _InfoRow(
            label: changed ? l10n.trackPriceAgreed : l10n.trackPrice,
            child: Text(
              l10n.pounds(
                formatPounds(changed ? job.totalPiastres : offer.pricePiastres),
              ),
              textAlign: TextAlign.end,
              style: value,
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: l10n.trackPayment,
            child: Text(
              l10n.trackPaymentValue,
              textAlign: TextAlign.end,
              style: value,
            ),
          ),
          const SizedBox(height: 8),
          _InfoRow(
            label: l10n.trackAddress,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  details.addressDetails,
                  textAlign: TextAlign.end,
                  style: value,
                ),
                Text(
                  details.addressLabel,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colors.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: context.appColors.inkMuted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    );
  }
}

/// "عندي مشكلة" and, until the work starts, cancelling.
class _Footer extends StatelessWidget {
  const _Footer({required this.details, required this.technician});

  final RequestDetails details;
  final String technician;

  Future<void> _cancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final honorific = context.readHonorific();
    final cubit = context.read<RequestCubit>();
    final danger = context.appColors.danger;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trackCancelQuestion),
        content: Text(l10n.trackCancelNote(honorific, technician)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.trackKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: danger),
            child: Text(l10n.trackCancel),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final busy = context.select<RequestCubit, RequestAction?>(
      (cubit) => cubit.state.busy,
    );
    final canCancel =
        details.stage == RequestStage.chosen ||
        details.stage == RequestStage.confirmed;
    final open = details.hasOpenComplaint;
    return Column(
      children: [
        if (!open || canCancel)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!open) ComplaintButton(requestId: details.id),
              if (!open && canCancel) const SizedBox(width: 8),
              if (canCancel)
                TextButton(
                  onPressed: busy == null ? () => _cancel(context) : null,
                  style: TextButton.styleFrom(
                    foregroundColor: colors.danger,
                    padding: const EdgeInsets.all(10),
                    textStyle: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: busy == RequestAction.cancel
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: colors.danger,
                          ),
                        )
                      : Text(l10n.trackCancel),
                ),
            ],
          ),
        if (canCancel) ...[
          const SizedBox(height: 2),
          Text(
            l10n.trackCancelNote(context.watchHonorific(), technician),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.5, color: colors.inkMuted),
          ),
        ],
        if (open) ...[const SizedBox(height: 8), const OpenComplaintNote()],
      ],
    );
  }
}
