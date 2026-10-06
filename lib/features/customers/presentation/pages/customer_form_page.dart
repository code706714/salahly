import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/digit_input_formatters.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/widgets/area_picker_sheet.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/presentation/cubit/customer_form_cubit.dart';
import 'package:salahly/features/customers/presentation/customer_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Adds a customer, or edits [customerId]. With [fromContacts] it starts
/// from the phone's contact picker.
///
/// Closes with the [Customer] saved, or the one who already had the
/// number picked, and with null when the technician backs out. Deleting
/// goes back to the customers tab.
class CustomerFormPage extends StatelessWidget {
  const CustomerFormPage({
    this.customerId,
    this.fromContacts = false,
    super.key,
  });

  final String? customerId;
  final bool fromContacts;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = CustomerFormCubit(
          customers: context.read(),
          contacts: context.read(),
          customerId: customerId,
          fromContacts: fromContacts,
        );
        unawaited(cubit.load());
        return cubit;
      },
      child: const CustomerFormView(),
    );
  }
}

class CustomerFormView extends StatelessWidget {
  const CustomerFormView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = context.watch<CustomerFormCubit>().state;
    return BlocListener<CustomerFormCubit, CustomerFormState>(
      listenWhen: (previous, current) => current.status != previous.status,
      listener: (context, state) {
        switch (state.status) {
          case CustomerFormStatus.saved:
            _close(context, state.saved);
          case CustomerFormStatus.cancelled:
            _close(context);
          case CustomerFormStatus.deleted:
            context.go(AppRoutes.technicianCustomers);
          case CustomerFormStatus.loading ||
              CustomerFormStatus.editing ||
              CustomerFormStatus.saving ||
              CustomerFormStatus.deleting:
            break;
        }
      },
      child: Scaffold(
        appBar: DetailHeader(
          title: state.isEditing
              ? l10n.customerEditTitle
              : l10n.customerNewTitle,
        ),
        body: switch (state.status) {
          CustomerFormStatus.loading => const Center(
            child: CircularProgressIndicator(),
          ),
          CustomerFormStatus.cancelled ||
          CustomerFormStatus.saved ||
          CustomerFormStatus.deleted => const SizedBox.shrink(),
          _ => const _Form(),
        },
      ),
    );
  }
}

/// Hands [customer] back to the screen that opened the form, or shows the
/// customers tab when nothing did.
void _close(BuildContext context, [Customer? customer]) {
  if (context.canPop()) {
    context.pop(customer);
  } else {
    context.go(AppRoutes.technicianCustomers);
  }
}

class _Form extends StatelessWidget {
  const _Form();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final cubit = context.read<CustomerFormCubit>();
    final state = context.watch<CustomerFormCubit>().state;
    final failure = state.failure;
    final duplicate = state.duplicate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
            children: [
              Text(l10n.customerName, style: textTheme.labelLarge),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: state.name,
                onChanged: cubit.nameChanged,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(maxNameLength),
                ],
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(
                  hintText: l10n.customerNameHint,
                  errorText: state.showErrors && !state.isNameValid
                      ? l10n.customerNameInvalid
                      : null,
                ),
              ),
              const SizedBox(height: 18),
              Text(l10n.customerPhone, style: textTheme.labelLarge),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: state.phoneText,
                onChanged: cubit.phoneChanged,
                keyboardType: TextInputType.phone,
                inputFormatters: digitInputFormatters(maxLength: 11),
                textDirection: TextDirection.ltr,
                textInputAction: TextInputAction.next,
                style: const TextStyle(fontSize: 17, letterSpacing: 0.5),
                decoration: InputDecoration(
                  hintText: l10n.customerPhoneHint,
                  hintTextDirection: TextDirection.ltr,
                  errorText: state.showErrors && !state.isPhoneValid
                      ? l10n.phoneInvalid
                      : null,
                ),
              ),
              if (duplicate != null) ...[
                const SizedBox(height: 10),
                _Duplicate(customer: duplicate, isEditing: state.isEditing),
              ],
              const SizedBox(height: 18),
              Text(l10n.customerArea, style: textTheme.labelLarge),
              const SizedBox(height: 10),
              _AreaField(areaId: state.areaId),
              const SizedBox(height: 18),
              Text(l10n.customerAddress, style: textTheme.labelLarge),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: state.address,
                onChanged: cubit.addressChanged,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(hintText: l10n.customerAddressHint),
              ),
              const SizedBox(height: 18),
              Text(l10n.customerNotesLabel, style: textTheme.labelLarge),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: state.notes,
                onChanged: cubit.notesChanged,
                minLines: 2,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                style: const TextStyle(fontSize: 17),
                decoration: InputDecoration(hintText: l10n.customerNotesHint),
              ),
              if (state.isEditing && state.canDelete) ...[
                const SizedBox(height: 24),
                Center(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: colors.danger),
                    onPressed: state.isBusy ? null : () => _delete(context),
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    label: Text(l10n.customerDelete),
                  ),
                ),
              ],
            ],
          ),
        ),
        BottomActionBar(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failure != null) ...[
                Text(
                  commonFailureMessage(l10n, failure),
                  style: TextStyle(color: colors.danger, fontSize: 14),
                ),
                const SizedBox(height: 8),
              ],
              BusyFilledButton(
                label: l10n.customerSave,
                isBusy: state.status == CustomerFormStatus.saving,
                onPressed: state.isBusy ? null : cubit.save,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.customerSavesOffline,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<CustomerFormCubit>();
    final name = cubit.state.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(l10n.customerDeleteTitle(normalizeName(name))),
        content: Text(l10n.customerDeleteBody(customerGender(name))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.back),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.danger),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.customerDeleteConfirm),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await cubit.delete();
  }
}

/// The number belongs to [customer] already; offers to open them instead.
class _Duplicate extends StatelessWidget {
  const _Duplicate({required this.customer, required this.isEditing});

  final Customer customer;
  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: colors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.customerExists(customer.name),
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w600,
                color: colors.warning,
              ),
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: colors.primary),
            // A new customer's form hands back the one found instead; an
            // edit stays open underneath.
            onPressed: () => isEditing
                ? context.push(AppRoutes.customer(customer.id))
                : _close(context, customer),
            child: Text(l10n.customerOpen),
          ),
        ],
      ),
    );
  }
}

/// The area, picked from the catalog's list.
class _AreaField extends StatelessWidget {
  const _AreaField({required this.areaId});

  final String? areaId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<CustomerFormCubit>();
    final areas = context.watch<AreasCubit>().state;
    final name = areas.nameOf(areaId);

    Future<void> pick() async {
      final picked = await showAreaPicker(context, areas: areas.areas);
      if (picked != null) cubit.areaChanged(picked.id);
    }

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: BorderSide(color: colors.fieldBorder, width: 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.md),
        onTap: pick,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
            child: Row(
              spacing: 8,
              children: [
                Icon(Icons.place_outlined, size: 22, color: colors.inkMuted),
                Expanded(
                  child: Text(
                    name ?? l10n.areaPickerTitle,
                    style: TextStyle(
                      fontSize: 17,
                      color: name == null ? colors.inkMuted : colors.ink,
                    ),
                  ),
                ),
                if (areaId == null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 10),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: colors.inkMuted,
                    ),
                  )
                else
                  IconButton(
                    tooltip: l10n.customerAreaClear,
                    onPressed: () => cubit.areaChanged(null),
                    icon: Icon(Icons.close_rounded, color: colors.inkMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
