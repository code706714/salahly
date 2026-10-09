import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/presentation/admin_labels.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_actions_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/settings_form_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/add_pack_dialog.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/free_uses.dart';
import 'package:salahly/features/admin/presentation/widgets/settings/settings_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What one side gets and can buy: the uses a new account gets for free,
/// the price of each pack and whether it is on sale, and a way to add
/// another pack. The technicians' card also holds the launch target.
class PacksCard extends StatelessWidget {
  const PacksCard({required this.role, super.key});

  final UserRole role;

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<SettingsActionsCubit>();
    final pack = await showAddPackDialog(context, role: role);
    if (pack != null) await cubit.addPack(pack);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final form = context.watch<SettingsFormCubit>();
    final state = form.state;
    final isBusy = context.select<SettingsActionsCubit, bool>(
      (cubit) => cubit.state.isBusy,
    );
    final packs = state.original.packsOf(role);

    return SettingsCard(
      title: switch (role) {
        UserRole.consumer => l10n.adminSettingsConsumerPacks,
        UserRole.technician => l10n.adminSettingsTechnicianPacks,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          switch (role) {
            UserRole.consumer => FreeUsesStepper(
              label: l10n.adminSettingsConsumerFree,
              value: state.consumerFreeRequests,
              onChanged: form.consumerFreeRequestsChanged,
            ),
            UserRole.technician => FreeUsesStepper(
              label: l10n.adminSettingsTechnicianFree,
              value: state.technicianFreeJobs,
              onChanged: form.technicianFreeJobsChanged,
            ),
          },
          if (role == UserRole.technician) ...[
            const SizedBox(height: 14),
            const TargetField(),
          ],
          const Divider(height: 28),
          for (final pack in packs) ...[
            _PackRow(
              pack: pack,
              price: state.packPrices[pack.id],
              isActive: state.packActive[pack.id] ?? pack.isActive,
              onPriceChanged: (text) => form.packPriceChanged(pack.id, text),
              onActiveChanged: (isActive) =>
                  form.packActiveChanged(pack.id, isActive: isActive),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            switch (role) {
              UserRole.consumer => l10n.adminSettingsConsumerPacksNote,
              UserRole.technician => l10n.adminSettingsTechnicianPacksNote,
            },
            style: Theme.of(context).textTheme.bodySmall,
          ),
          // Adding a pack loads the settings anew, which would drop what is
          // typed and not saved yet; the tooltip says to save first.
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Tooltip(
              message: state.hasChanges ? l10n.adminSettingsSave : '',
              child: TextButton(
                onPressed: isBusy || state.hasChanges
                    ? null
                    : () => unawaited(_add(context)),
                child: Text(l10n.adminSettingsAddPack),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({
    required this.pack,
    required this.price,
    required this.isActive,
    required this.onPriceChanged,
    required this.onActiveChanged,
  });

  final CreditPackSetting pack;

  /// Null while what was typed is not a valid price.
  final int? price;
  final bool isActive;
  final ValueChanged<String> onPriceChanged;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = adminPackLabel(l10n, pack.role, pack.uses);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(
          width: 130,
          child: TextFormField(
            initialValue: pack.pricePiastres % 100 == 0
                ? '${pack.pricePiastres ~/ 100}'
                : formatPounds(pack.pricePiastres),
            keyboardType: TextInputType.number,
            inputFormatters: digitInputFormatters(maxLength: 7),
            onChanged: onPriceChanged,
            decoration: InputDecoration(
              isDense: true,
              suffixText: l10n.currencyEgp,
              errorText: price == null
                  ? l10n.adminSettingsPackPriceInvalid
                  : null,
              errorMaxLines: 3,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          label: l10n.adminSettingsPackPrice(label),
          child: Tooltip(
            message: isActive
                ? l10n.adminSettingsPackOnSale
                : l10n.adminSettingsPackOffSale,
            child: Switch(value: isActive, onChanged: onActiveChanged),
          ),
        ),
      ],
    );
  }
}
