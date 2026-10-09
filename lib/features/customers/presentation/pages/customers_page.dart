import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/offline_banner.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/customers/presentation/add_customer.dart';
import 'package:salahly/features/customers/presentation/cubit/customers_cubit.dart';
import 'package:salahly/features/customers/presentation/widgets/customer_row.dart';
import 'package:salahly/features/customers/presentation/widgets/customers_empty.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The customers tab: everyone the technician works for, searchable.
class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CustomersCubit(
        customers: context.read(),
        areas: context.read<AreasCubit>().state.areas,
      )..start(),
      child: BlocListener<AreasCubit, AreasState>(
        listener: (context, areas) =>
            context.read<CustomersCubit>().areasChanged(areas.areas),
        child: const CustomersView(),
      ),
    );
  }
}

class CustomersView extends StatelessWidget {
  const CustomersView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CustomersCubit>().state;
    final total = state.customers?.length ?? 0;
    return Scaffold(
      body: SafeArea(
        child: PullToRefresh(
          onRefresh: () => context.read<SyncCubit>().syncNow(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              _Header(count: total),
              const OfflineBanner(padding: EdgeInsets.only(top: 14)),
              if (state.isEmpty)
                const CustomersEmpty()
              else if (!state.isLoading) ...[
                const SizedBox(height: 14),
                const _SearchField(),
                const SizedBox(height: 14),
                _FilterChips(state: state),
                const SizedBox(height: 14),
                _CustomerList(state: state),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Row(
      children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                text: l10n.customersTitle,
                children: [
                  if (count > 0)
                    TextSpan(
                      text: ' $count',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: colors.inkMuted,
                      ),
                    ),
                ],
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ),
        Material(
          color: colors.primary,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.sm),
            onTap: () => addCustomer(context, AppRoutes.newCustomer),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_rounded, size: 20, color: colors.onPrimary),
                    const SizedBox(width: 6),
                    Text(
                      l10n.customersAdd,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colors.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField();

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  late final _controller = TextEditingController(
    text: context.read<CustomersCubit>().state.query,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _changed(String query) {
    context.read<CustomersCubit>().queryChanged(query);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return TextField(
      controller: _controller,
      onChanged: _changed,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: l10n.customersSearchHint,
        hintStyle: TextStyle(fontSize: 16, color: colors.inkMuted),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 22,
          color: colors.inkMuted,
        ),
        suffixIcon: _controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: l10n.customersSearchClear,
                icon: const Icon(Icons.close_rounded, size: 20),
                color: colors.inkMuted,
                onPressed: () {
                  _controller.clear();
                  _changed('');
                },
              ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.state});

  final CustomersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<CustomersCubit>();
    final active = state.activeFilter;
    final chips = [
      for (final filter in CustomerFilter.values)
        if (filter == CustomerFilter.all || state.count(filter) > 0)
          _FilterChip(
            label: switch (filter) {
              CustomerFilter.all => l10n.customersFilterAll,
              CustomerFilter.owing => l10n.customersFilterOwing(
                state.count(filter),
              ),
              CustomerFilter.platform => l10n.customersFilterPlatform(
                state.count(filter),
              ),
              CustomerFilter.cleaningDue => l10n.customersFilterCleaning(
                state.count(filter),
              ),
            },
            selected: filter == active,
            onTap: () => cubit.filterChanged(filter),
          ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(spacing: 8, children: chips),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.ink : colors.surface,
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? colors.ink : colors.fieldBorder,
            width: 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? colors.background : colors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CustomerList extends StatelessWidget {
  const _CustomerList({required this.state});

  final CustomersState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final customers = state.visible;
    if (customers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Text(
          l10n.customersNoResults,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: colors.inkMuted),
        ),
      );
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, summary) in customers.indexed) ...[
            if (index > 0) const Divider(),
            CustomerRow(summary: summary, today: state.today),
          ],
        ],
      ),
    );
  }
}
