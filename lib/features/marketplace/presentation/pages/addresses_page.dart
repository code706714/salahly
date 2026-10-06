import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/presentation/cubit/addresses_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/address_form_sheet.dart';
import 'package:salahly/features/marketplace/presentation/widgets/address_summary.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The consumer's saved addresses: add, edit and delete.
class AddressesPage extends StatelessWidget {
  const AddressesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = AddressesCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const AddressesView(),
    );
  }
}

class AddressesView extends StatelessWidget {
  const AddressesView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final cubit = context.read<AddressesCubit>();
    final state = context.watch<AddressesCubit>().state;

    return BlocListener<AddressesCubit, AddressesState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              consumerFailureMessage(
                l10n,
                state.failure!,
                honorific: context.readHonorific(),
              ),
            ),
          ),
        ),
      child: Scaffold(
        appBar: DetailHeader(title: l10n.addressesTitle),
        body: switch (state.status) {
          AddressesStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          AddressesStatus.failed => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.addressesLoadFailed,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: colors.inkMuted),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: cubit.retry,
                    child: Text(l10n.consumerRetry(honorific)),
                  ),
                ],
              ),
            ),
          ),
          AddressesStatus.ready => ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              if (state.addresses.isEmpty)
                const _NoAddresses()
              else
                for (final address in state.addresses) ...[
                  _AddressRow(
                    address: address,
                    deleting: state.deleting == address.id,
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 4),
              if (state.isFull)
                Text(
                  l10n.consumerAddressLimit(honorific),
                  style: TextStyle(fontSize: 14, color: colors.inkMuted),
                )
              else
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ChoiceChipButton(
                    label: l10n.addressesNew,
                    icon: Icons.add_rounded,
                    selected: false,
                    onTap: () => showAddressForm(context, onSave: cubit.save),
                  ),
                ),
              const SizedBox(height: 16),
              const AddressPrivacyNote(),
            ],
          ),
        },
      ),
    );
  }
}

class _NoAddresses extends StatelessWidget {
  const _NoAddresses();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          children: [
            Icon(Icons.location_on_outlined, size: 32, color: colors.inkMuted),
            const SizedBox(height: 8),
            Text(
              l10n.addressesEmpty,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.addressesEmptyNote(context.watchHonorific()),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: colors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A saved address: tap to edit, or delete it after confirming.
class _AddressRow extends StatelessWidget {
  const _AddressRow({required this.address, required this.deleting});

  final ConsumerAddress address;
  final bool deleting;

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final honorific = context.readHonorific();
    final cubit = context.read<AddressesCubit>();
    final colors = context.appColors;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.xl),
        ),
        title: Text(
          l10n.addressesDeleteTitle(honorific, address.label),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        content: Text(
          l10n.addressesDeleteBody,
          style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.addressesKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            child: Text(l10n.addressesDeleteConfirm(honorific)),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.delete(address.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<AddressesCubit>();
    final honorific = context.watchHonorific();
    return AppCard(
      radius: AppRadii.lg,
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 4, 6),
      onTap: () => showAddressForm(
        context,
        address: address,
        onSave: (draft) => cubit.save(draft, id: address.id),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primarySoft,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(
              Icons.location_on_outlined,
              size: 22,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: AddressSummary(address: address),
            ),
          ),
          if (deleting)
            const SizedBox.square(
              dimension: 48,
              child: Center(
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              onPressed: () => _delete(context),
              tooltip: l10n.addressesDelete(honorific),
              constraints: const BoxConstraints.tightFor(width: 48, height: 48),
              icon: Icon(Icons.delete_outline_rounded, color: colors.inkMuted),
            ),
        ],
      ),
    );
  }
}
