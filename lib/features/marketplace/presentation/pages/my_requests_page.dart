import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/request_follow_up.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The "طلباتي" tab: requests in progress, then past ones.
///
/// The list lives in the [MyRequestsCubit] that `ConsumerScope` provides,
/// so there is no cubit to create here.
class MyRequestsPage extends StatelessWidget {
  const MyRequestsPage({super.key});

  @override
  Widget build(BuildContext context) => const MyRequestsView();
}

/// The consumer's requests, pulled down to fetch them again.
class MyRequestsView extends StatelessWidget {
  const MyRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<MyRequestsCubit>().state;
    final now = DateTime.now();
    return BlocListener<MyRequestsCubit, MyRequestsState>(
      // A refresh that failed while the list stays shown.
      listenWhen: (previous, current) =>
          current.status == MyRequestsStatus.ready &&
          current.failure != null &&
          previous.failure != current.failure,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                consumerFailureMessage(
                  l10n,
                  state.failure!,
                  honorific: context.readHonorific(),
                ),
              ),
            ),
          );
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (state.status) {
            MyRequestsStatus.loading => const _Loading(),
            MyRequestsStatus.failed => const _LoadFailed(),
            MyRequestsStatus.ready => RefreshIndicator(
              onRefresh: context.read<MyRequestsCubit>().load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  const _Title(),
                  if (state.requests.isEmpty)
                    const _Empty()
                  else ...[
                    ..._section(l10n.myRequestsActive, state.active, now),
                    ..._section(l10n.myRequestsPast, state.past, now),
                  ],
                ],
              ),
            ),
          },
        ),
      ),
    );
  }

  List<Widget> _section(
    String title,
    List<RequestSummary> requests,
    DateTime now,
  ) => [
    if (requests.isNotEmpty) ...[
      const SizedBox(height: 12),
      _SectionTitle(title),
      for (final request in requests) ...[
        const SizedBox(height: 12),
        _RequestCard(request: request, now: now),
      ],
    ],
  ];
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        AppLocalizations.of(context).navMyRequests,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 0),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: context.appColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

/// One request: its name, where it stands, and the day, technician and
/// price once picked.
class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.now});

  final RequestSummary request;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final stage = request.stage;
    final (pill, tone) = _pill(l10n, honorific);
    final technicianId = request.technicianId;
    final technician = request.technicianName;
    final over =
        stage == RequestStage.cancelled || stage == RequestStage.expired;
    final highlight =
        stage == RequestStage.confirmed || stage == RequestStage.started;
    return Opacity(
      opacity: over ? 0.8 : 1,
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderColor: highlight ? colors.primary : null,
        borderWidth: highlight ? 2 : 1.5,
        onTap: () => context.push(AppRoutes.request(request.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.watchRequestName(
                      request.categoryId,
                      request.issue,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // The pill keeps its full width unless the name needs room.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 190),
                  child: StatusPill(label: pill, tone: tone),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _line(l10n, honorific),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.inkMuted,
              ),
            ),
            if (stage == RequestStage.done &&
                technicianId != null &&
                technician != null)
              TextButton(
                onPressed: () => context.push(
                  AppRoutes.newRequestFor(
                    categoryId: request.categoryId,
                    technicianId: technicianId,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: colors.primary,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 48),
                  alignment: AlignmentDirectional.centerStart,
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(
                  l10n.myRequestsAgain(honorific, firstNameOf(technician)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  (String, PillTone) _pill(AppLocalizations l10n, String honorific) {
    final name = firstNameOf(request.technicianName ?? '');
    final stars = request.reviewStars;
    return switch (request.stage) {
      RequestStage.waitingForOffers => (
        l10n.myRequestsWaiting,
        PillTone.waiting,
      ),
      RequestStage.choosingOffer => (
        l10n.myRequestsOffers(request.offerCount),
        PillTone.attention,
      ),
      RequestStage.chosen => (l10n.myRequestsChosen(name), PillTone.waiting),
      RequestStage.confirmed => (
        l10n.myRequestsComing(
          name,
          _comingDay(l10n, request.scheduledAt ?? request.day),
        ),
        PillTone.attention,
      ),
      RequestStage.started => (
        l10n.myRequestsWorking(name),
        PillTone.attention,
      ),
      RequestStage.done when stars != null => (
        l10n.myRequestsRated(stars),
        PillTone.success,
      ),
      RequestStage.done => (l10n.myRequestsRate(honorific), PillTone.success),
      RequestStage.cancelled when _cancelledByTechnician => (
        l10n.myRequestsCancelledByTechnician,
        PillTone.neutral,
      ),
      RequestStage.cancelled => (
        l10n.myRequestsCancelledByYou(honorific),
        PillTone.neutral,
      ),
      RequestStage.expired => (l10n.myRequestsExpired, PillTone.neutral),
    };
  }

  /// "النهارده", "بكره", else the weekday within the week, else the date.
  String _comingDay(AppLocalizations l10n, DateTime day) =>
      switch (CalendarDate.daysBetween(now, day)) {
        0 => l10n.today,
        1 => l10n.tomorrow,
        > 1 && < 7 => weekdayName(day),
        _ => DateFormat('d MMMM', 'ar').format(day),
      };

  /// A job the technician called off has no request-level canceller.
  bool get _cancelledByTechnician =>
      request.cancelledBy == UserRole.technician ||
      (request.cancelledBy == null && request.jobStatus == JobStatus.cancelled);

  /// "السبت 12:00 الضهر · محمود السيد · 350 ج.م" while in progress, the
  /// date in the history, and how long ago it was sent before a pick.
  String _line(AppLocalizations l10n, String honorific) {
    final technician = request.technicianName;
    final price = request.pricePiastres;
    final when = request.scheduledAt ?? request.day;
    final picked = [
      ?technician,
      if (price != null) l10n.pounds(formatPounds(price)),
    ];
    final date = DateFormat('d MMMM', 'ar').format(when);
    return switch (request.stage) {
      RequestStage.waitingForOffers => [
        _sentAgo(l10n),
        l10n.myRequestsNoOffers,
      ].join(' · '),
      RequestStage.choosingOffer => _sentAgo(l10n),
      RequestStage.chosen ||
      RequestStage.confirmed ||
      RequestStage.started => [momentLabel(l10n, when), ...picked].join(' · '),
      RequestStage.done => [date, ...picked].join(' · '),
      RequestStage.cancelled || RequestStage.expired => [
        date,
        if (technician != null)
          technician
        else if (request.stage == RequestStage.expired &&
            request.offerCount == 0)
          l10n.myRequestsNoOffersCame
        else
          l10n.myRequestsBeforePick(honorific),
      ].join(' · '),
    };
  }

  String _sentAgo(AppLocalizations l10n) {
    final elapsed = now.difference(request.createdAt);
    if (elapsed.inMinutes < 60) {
      return l10n.myRequestsSentMinutes(elapsed.inMinutes.clamp(0, 59));
    }
    if (elapsed.inHours < 24) return l10n.myRequestsSentHours(elapsed.inHours);
    return l10n.myRequestsSentDays(elapsed.inDays);
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: const [
        _Title(),
        SizedBox(height: 80),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final failure = context.select<MyRequestsCubit, String?>(
      (cubit) => switch (cubit.state.failure) {
        final failure? => consumerFailureMessage(
          l10n,
          failure,
          honorific: honorific,
        ),
        null => null,
      },
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const _Title(),
        const SizedBox(height: 64),
        Icon(Icons.cloud_off_rounded, size: 48, color: colors.inkMuted),
        const SizedBox(height: 12),
        Text(
          l10n.myRequestsLoadFailed,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        if (failure != null) ...[
          const SizedBox(height: 6),
          Text(
            failure,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
          ),
        ],
        const SizedBox(height: 16),
        Center(
          child: FilledButton(
            onPressed: context.read<MyRequestsCubit>().load,
            child: Text(l10n.consumerRetry(honorific)),
          ),
        ),
      ],
    );
  }
}

/// No requests yet: an invitation to ask for a technician.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    return Padding(
      padding: const EdgeInsets.only(top: 64),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.format_list_bulleted_rounded,
              size: 34,
              color: colors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.myRequestsEmpty(honorific),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.myRequestsEmptyBody(honorific),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.7, color: colors.inkMuted),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => context.go(AppRoutes.consumerHome),
            child: Text(l10n.myRequestsEmptyAction(honorific)),
          ),
        ],
      ),
    );
  }
}
