import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// How far requests got: sent, offered on, chosen, finished. Each step also
/// says what share of the step before it got there.
class OverviewFunnel extends StatelessWidget {
  const OverviewFunnel({required this.funnel, super.key});

  final RequestFunnel funnel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final steps = [
      (funnel.sent, l10n.adminFunnelSent, false),
      (
        funnel.withOffer,
        l10n.adminFunnelWithOffer(_percent(funnel.withOffer, funnel.sent)),
        false,
      ),
      (
        funnel.chosen,
        l10n.adminFunnelChosen(_percent(funnel.chosen, funnel.withOffer)),
        false,
      ),
      (
        funnel.finished,
        l10n.adminFunnelFinished(_percent(funnel.finished, funnel.chosen)),
        true,
      ),
    ];
    return AppCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.adminFunnelTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (index, (count, label, done)) in steps.indexed) ...[
                  if (index > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        color: colors.dashedBorder,
                      ),
                    ),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: done ? colors.successSoft : colors.background,
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                color: done ? colors.success : colors.ink,
                              ),
                            ),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 14,
                                color: done ? colors.success : colors.inkMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static int _percent(int part, int whole) =>
      whole == 0 ? 0 : (part * 100 / whole).round();
}
