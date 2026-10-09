import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/request_view_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/confirm_choice_dialog.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The request before any offer arrives: who it went to and widening the time.
class WaitingView extends StatelessWidget {
  const WaitingView({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ClockCubit()..start(),
      child: _WaitingScreen(details: details),
    );
  }
}

class _WaitingScreen extends StatelessWidget {
  const _WaitingScreen({required this.details});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final now = context.watch<ClockCubit>().state;
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.category(details.categoryId)?.name,
    );
    final busy = context.select<RequestCubit, RequestAction?>(
      (cubit) => cubit.state.busy,
    );
    return Scaffold(
      appBar: DetailHeader(
        title: requestHeadline(l10n, details.issue, category: category),
        subtitle: requestWhenLabel(
          l10n,
          details.day,
          details.window,
          today: now,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: [
          _Hero(sentTo: details.sentTo),
          const SizedBox(height: AppSpacing.md),
          _Progress(details: details, now: now),
          const SizedBox(height: AppSpacing.md),
          _WidenCard(details: details, today: now, busy: busy),
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: switch (busy) {
                null => () => _cancel(context),
                RequestAction.cancel => () {},
                _ => null,
              },
              style: TextButton.styleFrom(
                foregroundColor: colors.danger,
                minimumSize: const Size(120, 48),
                textStyle: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: busy == RequestAction.cancel
                  ? SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: colors.danger,
                      ),
                    )
                  : Text(l10n.waitingCancel),
            ),
            const SizedBox(height: 2),
            Text(
              l10n.waitingCancelFree,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.inkMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<RequestCubit>();
    final confirmed = await showConfirmChoiceDialog(
      context,
      title: l10n.waitingCancelConfirmTitle,
      body: l10n.waitingCancelConfirmBody,
      keep: l10n.waitingCancelKeep(context.readHonorific()),
      confirm: l10n.waitingCancel,
      destructive: true,
    );
    if (confirmed) await cubit.cancel();
  }
}

/// The clock, "مستنيين العروض" and who the request went to.
class _Hero extends StatelessWidget {
  const _Hero({required this.sentTo});

  final int sentTo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 4),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: colors.warningSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 44,
              color: colors.warning,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.waitingTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 10),
          Text(
            '${l10n.waitingSentTo(sentTo)} '
            '${l10n.waitingCheckBack(context.watchHonorific())}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.7, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// How far the request got: sent, seen, and no offers yet.
class _Progress extends StatelessWidget {
  const _Progress({required this.details, required this.now});

  final RequestDetails details;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(
        children: [
          _Step(
            label: requestSentAgoLabel(l10n, details.createdAt, now: now),
            done: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Step(
            label: l10n.waitingSeenBy(details.seenBy),
            done: details.seenBy > 0,
          ),
          const SizedBox(height: AppSpacing.sm),
          _Step(label: l10n.waitingNoOffers, done: false),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.done});

  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      children: [
        Icon(
          done ? Icons.check_rounded : Icons.circle_outlined,
          size: done ? 26 : 22,
          color: done ? colors.successBright : colors.inkMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: done ? colors.ink : colors.inkMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// What happens after two hours without offers, and widening the time.
class _WidenCard extends StatelessWidget {
  const _WidenCard({
    required this.details,
    required this.today,
    required this.busy,
  });

  final RequestDetails details;
  final DateTime today;
  final RequestAction? busy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final widening = busy == RequestAction.widenWindow;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.inkSoft,
        borderRadius: BorderRadius.circular(AppRadii.xl),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              details.widened
                  ? l10n.waitingWidenedTitle
                  : l10n.waitingWidenTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: colors.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              details.widened ? l10n.waitingWidenedBody : l10n.waitingWidenBody,
              style: TextStyle(fontSize: 14, height: 1.7, color: colors.ink),
            ),
            const SizedBox(height: 10),
            if (details.window == RequestWindow.anyTime)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: colors.success,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.waitingWindowWidened(honorific),
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        fontWeight: FontWeight.w600,
                        color: colors.success,
                      ),
                    ),
                  ),
                ],
              )
            else
              FilledButton(
                onPressed: switch (busy) {
                  null => () => _widen(context),
                  RequestAction.widenWindow => () {},
                  _ => null,
                },
                style: FilledButton.styleFrom(
                  backgroundColor: colors.surface,
                  foregroundColor: colors.ink,
                  disabledBackgroundColor: colors.surface,
                  disabledForegroundColor: colors.inkMuted,
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  textStyle: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: widening
                    ? SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: colors.ink,
                        ),
                      )
                    : Text(
                        l10n.waitingWidenWindow(honorific),
                        textAlign: TextAlign.center,
                      ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _widen(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final honorific = context.readHonorific();
    final cubit = context.read<RequestCubit>();
    final confirmed = await showConfirmChoiceDialog(
      context,
      title: l10n.waitingWidenConfirmTitle(honorific),
      body: l10n.waitingWidenConfirmBody(
        requestDayName(l10n, details.day, today: today),
      ),
      keep: l10n.waitingKeepWindow(honorific),
      confirm: l10n.waitingWidenConfirm(honorific),
    );
    if (confirmed) await cubit.widenWindow();
  }
}
