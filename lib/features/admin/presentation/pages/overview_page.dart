import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/time/clock_cubit.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_tabs.dart';
import 'package:salahly/features/admin/presentation/widgets/overview/overview_attention.dart';
import 'package:salahly/features/admin/presentation/widgets/overview/overview_coverage.dart';
import 'package:salahly/features/admin/presentation/widgets/overview/overview_funnel.dart';
import 'package:salahly/features/admin/presentation/widgets/overview/overview_kpis.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<OverviewCubit>().state;
    final cubit = context.read<OverviewCubit>();
    final overview = state.overview;
    final coverage = state.coverage;

    return AdminPage(
      title: l10n.adminOverviewTitle,
      subtitle: l10n.adminOverviewSubtitle,
      trailing: AdminTabs<OverviewPeriod>(
        values: OverviewPeriod.values,
        selected: state.period,
        labelOf: (period) => overviewPeriodLabel(l10n, period),
        onSelected: cubit.selectPeriod,
      ),
      child: overview == null || coverage == null
          ? SizedBox(
              height: 320,
              child: state.failure != null
                  ? AdminFailureView(
                      failure: state.failure!,
                      onRetry: cubit.load,
                    )
                  : const Center(child: CircularProgressIndicator()),
            )
          : Opacity(
              opacity: state.isLoading ? 0.6 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OverviewKpis(overview: overview),
                  const SizedBox(height: 22),
                  OverviewFunnel(funnel: overview.funnel),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 10,
                        child: OverviewAttention(
                          overview: overview,
                          now: context.read<ClockCubit>().state,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 13,
                        child: OverviewCoverage(report: coverage),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
