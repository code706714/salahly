import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/money_text.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';
import 'package:salahly/core/widgets/whatsapp_button.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/customers/presentation/cubit/customer_cubit.dart';
import 'package:salahly/features/customers/presentation/customer_labels.dart';
import 'package:salahly/features/customers/presentation/customer_messages.dart';
import 'package:salahly/features/customers/presentation/widgets/unit_sheet.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One customer: how to reach them, what they owe, their units and jobs.
class CustomerPage extends StatelessWidget {
  const CustomerPage({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CustomerCubit(
        customers: context.read(),
        jobs: context.read(),
        customerId: customerId,
      )..start(),
      child: const CustomerView(),
    );
  }
}

class CustomerView extends StatelessWidget {
  const CustomerView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final state = context.watch<CustomerCubit>().state;
    final customer = state.record?.customer;

    return BlocListener<CustomerCubit, CustomerState>(
      listenWhen: (previous, current) =>
          current.failure != null && current.failure != previous.failure,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(commonFailureMessage(l10n, state.failure!))),
        ),
      child: _LeaveWhenGone(
        child: Scaffold(
          appBar: DetailHeader(
            title: customer?.name ?? '',
            trailing: customer == null
                ? null
                : TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onPressed: () =>
                        context.push(AppRoutes.editCustomer(customer.id)),
                    child: Text(l10n.customerEdit),
                  ),
          ),
          body: state.isLoading || customer == null
              ? const SizedBox.shrink()
              : _Body(state: state, customer: customer),
          bottomNavigationBar: customer == null
              ? null
              : BottomActionBar(
                  child: FilledButton.icon(
                    onPressed: () =>
                        context.push(AppRoutes.newJobFor(customer.id)),
                    icon: const Icon(Icons.add_rounded, size: 24),
                    label: Text(newJobForLabel(l10n, customer.name)),
                  ),
                ),
        ),
      ),
    );
  }
}

/// Leaves the page once the customer is deleted, here or on another
/// phone; when another screen is on top, as soon as this one shows again.
class _LeaveWhenGone extends StatefulWidget {
  const _LeaveWhenGone({required this.child});

  final Widget child;

  @override
  State<_LeaveWhenGone> createState() => _LeaveWhenGoneState();
}

class _LeaveWhenGoneState extends State<_LeaveWhenGone> {
  bool _left = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _leaveIfGone();
  }

  void _leaveIfGone() {
    final isCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (_left || !isCurrent || !context.read<CustomerCubit>().state.isGone) {
      return;
    }
    _left = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRoutes.technicianCustomers);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<CustomerCubit, CustomerState>(
      listenWhen: (previous, current) => current.isGone && !previous.isGone,
      listener: (context, state) => _leaveIfGone(),
      child: widget.child,
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.customer});

  final CustomerState state;
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final phone = customer.phone;
    final notes = customer.notes;
    final jobs = state.jobs ?? const <JobSummary>[];
    return PullToRefresh(
      onRefresh: () => context.read<SyncCubit>().syncNow(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (phone != null) ...[
            _ContactButtons(phone: phone),
            const SizedBox(height: 14),
          ],
          if (state.owedPiastres > 0) ...[
            _OwedCard(state: state, customer: customer),
            const SizedBox(height: 14),
          ],
          if (phone != null ||
              customer.address != null ||
              customer.areaId != null) ...[
            _DetailsCard(customer: customer),
            const SizedBox(height: 14),
          ],
          _UnitsCard(state: state, customer: customer),
          if (notes != null) ...[
            const SizedBox(height: 14),
            _Card(
              label: AppLocalizations.of(context).customerNotes,
              children: [
                Text(notes, style: const TextStyle(fontSize: 15, height: 1.7)),
              ],
            ),
          ],
          if (jobs.isNotEmpty) ...[
            const SizedBox(height: 14),
            _JobsCard(jobs: jobs, today: state.today),
          ],
        ],
      ),
    );
  }
}

/// A titled card of the customer page.
class _Card extends StatelessWidget {
  const _Card({required this.label, required this.children, this.gap = 10});

  final String label;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: [
          Semantics(
            header: true,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.inkMuted,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ContactButtons extends StatelessWidget {
  const _ContactButtons({required this.phone});

  final PhoneNumber phone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return SizedBox(
      height: 52,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          Expanded(
            child: Material(
              color: colors.inkSoft,
              borderRadius: BorderRadius.circular(AppRadii.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.md),
                onTap: () => context.dial(phone),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 8,
                  children: [
                    Icon(Icons.phone_outlined, size: 20, color: colors.ink),
                    Text(
                      l10n.customerCall,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: WhatsAppButton(
              label: l10n.customerWhatsapp,
              onPressed: () => context.sendOnWhatsApp('', to: phone),
            ),
          ),
        ],
      ),
    );
  }
}

class _OwedCard extends StatelessWidget {
  const _OwedCard({required this.state, required this.customer});

  final CustomerState state;
  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final gender = customerGender(customer.name);
    final phone = customer.phone;
    final paid = state.owedPaidPiastres;
    final technicianName = context.select<SessionCubit, String>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile.fullName,
        _ => '',
      },
    );
    return AppCard(
      color: colors.dangerFaint,
      borderColor: colors.dangerLine,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.customerOwes(gender),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.dangerDeep,
                      ),
                    ),
                    MoneyText(
                      state.owedPiastres,
                      currencyScale: 16 / 28,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: colors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              if (paid > 0)
                Text(
                  l10n.customerPaidOf(
                    gender,
                    formatPounds(paid),
                    formatPounds(state.owedTotalPiastres),
                  ),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.dangerDeep,
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 8,
              children: [
                if (phone != null)
                  Expanded(
                    child: WhatsAppButton(
                      label: gender == 'female'
                          ? l10n.remindCustomerFeminine
                          : l10n.remindCustomer,
                      outlined: true,
                      onPressed: () => context.sendOnWhatsApp(
                        customerReminderMessage(
                          l10n,
                          customerName: customer.name,
                          owed: state.owedJobs,
                          technicianName: technicianName,
                        ),
                        to: phone,
                      ),
                    ),
                  ),
                Expanded(
                  child: Material(
                    color: colors.ink,
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      onTap: () => context.push(
                        AppRoutes.jobInvoice(state.owedJobs.first.job.id),
                      ),
                      child: Center(
                        child: Text(
                          l10n.customerRecordPayment,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.background,
                          ),
                        ),
                      ),
                    ),
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

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.customer});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final phone = customer.phone;
    final areaName = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(customer.areaId),
    );
    final place = [?customer.address, ?areaName].join('، ');
    return _Card(
      label: l10n.customerDetails,
      gap: 0,
      children: [
        if (phone != null)
          _DetailRow(
            icon: Icons.phone_outlined,
            onTap: () => context.dial(phone),
            child: Text(
              phone.local,
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 15),
            ),
          ),
        if (place.isNotEmpty)
          _DetailRow(
            icon: Icons.place_outlined,
            onTap: () => context.openMap(place),
            child: Text(
              place,
              style: const TextStyle(fontSize: 15, height: 1.6),
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          spacing: 8,
          children: [
            Icon(icon, size: 20, color: colors.inkMuted),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

class _UnitsCard extends StatelessWidget {
  const _UnitsCard({required this.state, required this.customer});

  final CustomerState state;
  final Customer customer;

  Future<void> _edit(BuildContext context, {CustomerUnit? unit}) async {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<CustomerCubit>();
    final result = await showUnitSheet(context, today: state.today, unit: unit);
    switch (result) {
      case null:
        return;
      case UnitSaved(:final draft):
        await cubit.saveUnit(draft, unitId: unit?.id);
      case UnitDeleteRequested():
        final deleted = await cubit.deleteUnit(unit!.id);
        if (!deleted || !context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.unitDeleted),
              action: SnackBarAction(
                label: l10n.unitRestore,
                textColor: colors.brassLight,
                onPressed: () => cubit.restoreUnit(unit),
              ),
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final units = state.record?.units ?? const <CustomerUnit>[];
    final nextService = state.nextServiceOn;
    return _Card(
      label: l10n.customerUnits(customerGender(customer.name)),
      gap: 0,
      children: [
        if (units.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l10n.customerNoUnits,
              style: TextStyle(fontSize: 15, color: colors.inkMuted),
            ),
          ),
        for (final unit in units)
          InkWell(
            onTap: () => _edit(context, unit: unit),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                spacing: 10,
                children: [
                  Expanded(
                    child: Text(
                      unitTitle(l10n, unit),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  if (unit.installedYear case final year?)
                    Text(
                      l10n.unitSince(year),
                      style: TextStyle(fontSize: 15, color: colors.inkMuted),
                    ),
                ],
              ),
            ),
          ),
        if (nextService != null) ...[
          const SizedBox(height: 6),
          _NextService(day: nextService, today: state.today),
        ],
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              minimumSize: const Size(48, 48),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => _edit(context),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(l10n.unitAdd),
          ),
        ),
      ],
    );
  }
}

/// "التنظيف الجاي: أول أبريل", or how late it is.
class _NextService extends StatelessWidget {
  const _NextService({required this.day, required this.today});

  final DateTime day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final isLate = CalendarDate.daysBetween(today, day) < 0;
    final foreground = isLate ? colors.dangerDeep : colors.warning;
    final label = serviceDayLabel(l10n, day, today: today);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isLate ? colors.dangerSoft : colors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        spacing: 8,
        children: [
          Icon(Icons.calendar_today_outlined, size: 18, color: foreground),
          Expanded(
            child: Text(
              isLate
                  ? l10n.customerCleaningLate(label)
                  : l10n.customerNextCleaning(label),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JobsCard extends StatelessWidget {
  const _JobsCard({required this.jobs, required this.today});

  final List<JobSummary> jobs;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return _Card(
      label: l10n.customerJobs(jobs.length),
      gap: 0,
      children: [
        const SizedBox(height: 4),
        for (final (index, summary) in jobs.indexed) ...[
          if (index > 0) const Divider(),
          _JobRow(summary: summary, today: today),
        ],
      ],
    );
  }
}

class _JobRow extends StatelessWidget {
  const _JobRow({required this.summary, required this.today});

  final JobSummary summary;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final job = summary.job;
    final balance = summary.balancePiastres;
    final (status, statusColor) = switch (job.status) {
      JobStatus.finished when balance > 0 => (
        l10n.customerJobBalance(formatPounds(balance)),
        colors.danger,
      ),
      JobStatus.finished || JobStatus.paid || JobStatus.confirmed => (
        jobStatusLabel(l10n, job.status),
        colors.success,
      ),
      JobStatus.unconfirmed => (
        jobStatusLabel(l10n, job.status),
        colors.primaryPressed,
      ),
      JobStatus.started => (jobStatusLabel(l10n, job.status), colors.warning),
      JobStatus.cancelled => (
        jobStatusLabel(l10n, job.status),
        colors.inkMuted,
      ),
    };
    return InkWell(
      onTap: () => context.push(AppRoutes.job(job.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          spacing: 10,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    jobTitle(l10n, job),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    shortDate(job.scheduledAt ?? job.createdAt, today: today),
                    style: TextStyle(fontSize: 13, color: colors.inkMuted),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (summary.totalPiastres > 0)
                  Text(
                    formatPounds(summary.totalPiastres),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                Text(
                  status,
                  style: TextStyle(fontSize: 13, color: statusColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
