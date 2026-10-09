import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/presentation/customer_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A customer in the list: who, where, what is going on with them, and
/// what they owe. Opens the customer.
class CustomerRow extends StatelessWidget {
  const CustomerRow({required this.summary, required this.today, super.key});

  final CustomerSummary summary;

  /// Local midnight of the current day.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final customer = summary.customer;
    final isPlatform = customer.source == CustomerSource.platform;
    final areaName = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(customer.areaId),
    );
    final subtitle = [
      ?areaName,
      if (isPlatform) l10n.customersFromPlatform,
      customerActivity(l10n, summary, today: today),
    ].join(' · ');

    return InkWell(
      onTap: () => context.push(AppRoutes.customer(customer.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            InitialsAvatar(
              name: customer.name,
              size: 44,
              color: isPlatform ? colors.primarySoft : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: colors.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Owed(summary: summary, today: today),
          ],
        ),
      ),
    );
  }
}

/// What the customer owes, or a chevron when nothing.
class _Owed extends StatelessWidget {
  const _Owed({required this.summary, required this.today});

  final CustomerSummary summary;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final owed = summary.owedPiastres;
    if (owed == 0) {
      return Icon(
        Icons.chevron_right_rounded,
        size: 20,
        color: colors.dashedBorder,
      );
    }
    final since = summary.owedSince;
    // Money for work finished today is only due, not owed yet.
    final isDue = since != null && CalendarDate.daysBetween(since, today) == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          formatPounds(owed),
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.5,
            color: isDue ? colors.warning : colors.danger,
          ),
        ),
        Text(
          isDue
              ? l10n.customersDue
              : l10n.customersOwes(customerGender(summary.customer.name)),
          style: TextStyle(
            fontSize: 12,
            height: 1.5,
            color: isDue ? colors.warning : colors.dangerDeep,
          ),
        ),
      ],
    );
  }
}
