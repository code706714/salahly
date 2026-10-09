import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_thread_cubit.dart';
import 'package:salahly/features/marketplace/presentation/request_view_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Shows the price talk of an offer, oldest step first, as [viewer] reads
/// it ("إنت" for their own steps). [fetch] reads it from the server;
/// [honorific] words the consumer's own steps.
Future<void> showOfferThreadSheet(
  BuildContext context, {
  required Future<Result<OfferThread?>> Function() fetch,
  required UserRole viewer,
  String honorific = 'other',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => BlocProvider(
      create: (context) {
        final cubit = OfferThreadCubit(fetch: fetch);
        unawaited(cubit.load());
        return cubit;
      },
      child: OfferThreadView(viewer: viewer, honorific: honorific),
    ),
  );
}

/// The sheet's content, reading [OfferThreadCubit].
class OfferThreadView extends StatelessWidget {
  const OfferThreadView({
    required this.viewer,
    this.honorific = 'other',
    super.key,
  });

  final UserRole viewer;
  final String honorific;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final state = context.watch<OfferThreadCubit>().state;
    final now = DateTime.now();
    final thread = state.thread;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.offerThreadTitle,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          if (thread != null)
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final event in thread.events)
                    _EventRow(
                      event: event,
                      viewer: viewer,
                      honorific: honorific,
                      now: now,
                    ),
                ],
              ),
            )
          else if (state.status == OfferThreadStatus.loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text(
              state.status == OfferThreadStatus.missing
                  ? l10n.marketplaceNotFound
                  : l10n.offerThreadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: colors.inkMuted),
            ),
            if (state.status == OfferThreadStatus.failed) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: context.read<OfferThreadCubit>().load,
                child: Text(l10n.retry),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.event,
    required this.viewer,
    required this.honorific,
    required this.now,
  });

  final OfferEvent event;
  final UserRole viewer;
  final String honorific;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final own = event.actor == viewer;
    final icon = switch (event.kind) {
      OfferEventKind.offer => Icons.sell_outlined,
      OfferEventKind.counter => Icons.swap_vert_rounded,
      OfferEventKind.revise => Icons.trending_down_rounded,
      OfferEventKind.acceptCounter => Icons.check_circle_outline_rounded,
      OfferEventKind.withdraw => Icons.person_off_outlined,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: own ? colors.primary : colors.inkMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offerEventText(
                    l10n,
                    event,
                    viewer: viewer,
                    honorific: honorific,
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
                Text(
                  '${requestDayName(l10n, event.createdAt, today: now)} '
                  '${clockTime(event.createdAt)}',
                  style: TextStyle(fontSize: 13, color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One step of the talk in words, as [viewer] reads it: "الفني نزّل السعر
/// لـ 300 ج.م", or "نزّلت السعر لـ 300 ج.م" for the technician's own step.
String offerEventText(
  AppLocalizations l10n,
  OfferEvent event, {
  required UserRole viewer,
  required String honorific,
}) {
  final piastres = event.pricePiastres;
  final price = piastres == null ? '' : l10n.pounds(formatPounds(piastres));
  return switch (viewer) {
    UserRole.consumer => switch (event.kind) {
      OfferEventKind.offer => l10n.threadConsumerOffer(price),
      OfferEventKind.counter => l10n.threadConsumerCounter(honorific, price),
      OfferEventKind.revise => l10n.threadConsumerRevise(price),
      OfferEventKind.acceptCounter => l10n.threadConsumerAccept(price),
      OfferEventKind.withdraw => l10n.threadConsumerWithdraw,
    },
    UserRole.technician => switch (event.kind) {
      OfferEventKind.offer => l10n.threadTechnicianOffer(price),
      OfferEventKind.counter => l10n.threadTechnicianCounter(price),
      OfferEventKind.revise => l10n.threadTechnicianRevise(price),
      OfferEventKind.acceptCounter => l10n.threadTechnicianAccept(price),
      OfferEventKind.withdraw => l10n.threadTechnicianWithdraw,
    },
  };
}
