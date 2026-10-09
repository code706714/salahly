import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/offline_banner.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';
import 'package:salahly/core/widgets/section_header.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/money/presentation/cubit/money_cubit.dart';
import 'package:salahly/features/money/presentation/money_labels.dart';
import 'package:salahly/features/money/presentation/widgets/income_card.dart';
import 'package:salahly/features/money/presentation/widgets/month_picker_sheet.dart';
import 'package:salahly/features/money/presentation/widgets/owed_list.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The money tab: a month's income and who still owes money.
class MoneyPage extends StatelessWidget {
  const MoneyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MoneyCubit(jobs: context.read())..start(),
      child: const MoneyView(),
    );
  }
}

class MoneyView extends StatelessWidget {
  const MoneyView({super.key});

  @override
  Widget build(BuildContext context) {
    final technicianName = context.select<SessionCubit, String?>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile.fullName,
        _ => null,
      },
    );
    // Briefly null while signing out, before the redirect.
    if (technicianName == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final state = context.watch<MoneyCubit>().state;
    final owed = state.owed;

    return Scaffold(
      body: SafeArea(
        child: PullToRefresh(
          onRefresh: () => context.read<SyncCubit>().syncNow(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _Header(state: state),
              const OfflineBanner(padding: EdgeInsets.only(top: 16)),
              const SizedBox(height: 16),
              IncomeCard(
                month: state.month,
                today: state.today,
                income: state.income,
              ),
              if (state.awaitingPayment != null) ...[
                const SizedBox(height: 16),
                SectionHeader(
                  title: l10n.moneyOwingTitle,
                  note: owed.isEmpty
                      ? null
                      : l10n.moneyOwingCustomers(state.owingCustomers),
                ),
                const SizedBox(height: 16),
                if (owed.isEmpty)
                  const _NobodyOwes()
                else
                  OwedList(
                    jobs: owed,
                    today: state.today,
                    technicianName: technicianName,
                  ),
                if (owed.any((job) => job.canRemind)) ...[
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      l10n.moneyRemindNote,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: colors.inkMuted,
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final MoneyState state;

  Future<void> _pickMonth(BuildContext context) async {
    final cubit = context.read<MoneyCubit>();
    final month = await showMonthPicker(
      context,
      months: state.months,
      selected: state.month,
    );
    if (month != null) cubit.selectMonth(month);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              l10n.navMoney,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Semantics(
          button: true,
          child: Material(
            color: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              side: BorderSide(color: colors.border, width: 1.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => _pickMonth(context),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        monthYear(state.month),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: colors.ink,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Nobody owes anything: a calm note instead of an empty list.
class _NobodyOwes extends StatelessWidget {
  const _NobodyOwes();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            l10n.moneyNobodyOwes,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.moneyNobodyOwesHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}
