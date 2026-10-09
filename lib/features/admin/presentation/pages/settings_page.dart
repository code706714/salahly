import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/domain/repositories/overview_repository.dart';
import 'package:salahly/features/admin/domain/repositories/settings_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_actions_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_form_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_action_listener.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_dialogs.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_page.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/accounts_card.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/areas_card.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/packs_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The numbers the platform runs on: free uses, the packs and their prices,
/// where people send money, and the areas.
///
/// Free uses, prices and accounts are edited and saved together; an area is
/// saved as soon as it changes.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final cubit = SettingsCubit(
              settingsRepository: context.read<SettingsRepository>(),
              overviewRepository: context.read<OverviewRepository>(),
            );
            unawaited(cubit.load());
            return cubit;
          },
        ),
        BlocProvider(
          create: (context) =>
              SettingsActionsCubit(context.read<SettingsRepository>()),
        ),
      ],
      child: const _SettingsView(),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SettingsCubit>().state;
    final settings = state.settings;
    final coverage = state.coverage;

    final Widget body;
    if (settings == null || coverage == null) {
      body = SizedBox(
        height: 320,
        child: state.failure != null
            ? AdminFailureView(
                failure: state.failure!,
                onRetry: context.read<SettingsCubit>().load,
              )
            : const Center(child: CircularProgressIndicator()),
      );
    } else {
      // A new form for settings that changed on the server, so what is
      // typed always starts from what is saved.
      body = BlocProvider(
        key: ValueKey(settings),
        create: (context) => SettingsFormCubit(settings),
        child: _SettingsForm(coverage: coverage),
      );
    }

    return AdminActionListener<SettingsActionsCubit>(
      onChanged: () {
        unawaited(context.read<SettingsCubit>().load());
        unawaited(context.read<OverviewCubit>().refresh());
      },
      child: body,
    );
  }
}

class _SettingsForm extends StatelessWidget {
  const _SettingsForm({required this.coverage});

  final AreaCoverageReport coverage;

  Future<void> _save(BuildContext context, AppLocalizations l10n) async {
    final actions = context.read<SettingsActionsCubit>();
    final form = context.read<SettingsFormCubit>().state;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.adminSettingsSaveTitle,
      body: l10n.adminSettingsSaveBody,
      confirmLabel: l10n.adminSettingsSaveConfirm,
    );
    if (confirmed) await actions.save(form);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = context.watch<SettingsFormCubit>().state;
    final isBusy = context.select<SettingsActionsCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );
    return AdminPage(
      title: l10n.adminSettingsTitle,
      subtitle: l10n.adminSettingsSubtitle,
      trailing: SizedBox(
        width: 200,
        child: BusyFilledButton(
          label: l10n.adminSettingsSave,
          isBusy: isBusy,
          onPressed: form.hasChanges && form.isValid
              ? () => unawaited(_save(context, l10n))
              : null,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: PacksCard(role: UserRole.consumer)),
              SizedBox(width: 16),
              Expanded(child: PacksCard(role: UserRole.technician)),
              SizedBox(width: 16),
              Expanded(child: AccountsCard()),
            ],
          ),
          const SizedBox(height: 16),
          AreasCard(report: coverage),
        ],
      ),
    );
  }
}
