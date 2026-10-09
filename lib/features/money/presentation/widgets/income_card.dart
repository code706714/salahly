import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/money_text.dart';
import 'package:salahly/features/jobs/domain/entities/month_income.dart';
import 'package:salahly/features/money/presentation/money_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A month's income on a dark card: the total, how many jobs it came from,
/// and how much of it was collected and how much is still out.
class IncomeCard extends StatelessWidget {
  const IncomeCard({
    required this.month,
    required this.today,
    required this.income,
    super.key,
  });

  final DateTime month;
  final DateTime today;

  /// Null while loading: the card keeps its size with the numbers hidden.
  final MonthIncome? income;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final income = this.income ?? MonthIncome.empty;
    final muted = TextStyle(fontSize: 14, color: colors.onInkMuted);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colors.ink,
        borderRadius: BorderRadius.circular(AppRadii.xxl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            incomeTitle(l10n, month, today: today),
            style: muted.copyWith(fontSize: 15),
          ),
          Opacity(
            opacity: this.income == null ? 0 : 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 2),
                MoneyText(
                  income.totalPiastres,
                  currencyScale: 18 / 34,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: colors.background,
                  ),
                ),
                const SizedBox(height: 2),
                Text(l10n.moneyFromJobs(income.jobCount), style: muted),
                const SizedBox(height: 14),
                _SplitBar(
                  collected: income.collectedPiastres,
                  outstanding: income.outstandingPiastres,
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _Legend(
                        label: l10n.moneyCollected,
                        color: colors.chartCollected,
                        piastres: income.collectedPiastres,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Legend(
                        label: l10n.moneyOutstanding,
                        color: colors.chartOutstanding,
                        piastres: income.outstandingPiastres,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Collected then outstanding, in proportion; an empty track when the
/// month has nothing yet.
class _SplitBar extends StatelessWidget {
  const _SplitBar({required this.collected, required this.outstanding});

  final int collected;
  final int outstanding;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 10,
          color: colors.inkMuted,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (collected > 0)
                Expanded(
                  flex: collected,
                  child: ColoredBox(color: colors.chartCollected),
                ),
              if (outstanding > 0)
                Expanded(
                  flex: outstanding,
                  child: ColoredBox(color: colors.chartOutstanding),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.label,
    required this.color,
    required this.piastres,
  });

  final String label;
  final Color color;
  final int piastres;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontSize: 14, color: colors.onInkMuted),
              ),
            ),
          ],
        ),
        MoneyText(
          piastres,
          currencyScale: 1,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: colors.background,
          ),
        ),
      ],
    );
  }
}
