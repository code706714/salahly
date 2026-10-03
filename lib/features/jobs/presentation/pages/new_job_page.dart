import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/dashed_rrect_border.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/cubit/new_job_cubit.dart';
import 'package:salahly/features/jobs/presentation/job_messages.dart';
import 'package:salahly/features/jobs/presentation/widgets/customer_picker_sheet.dart';
import 'package:salahly/features/jobs/presentation/widgets/schedule_picker.dart';
import 'package:salahly/features/jobs/presentation/widgets/tag_chips.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Records a new job.
class NewJobPage extends StatelessWidget {
  const NewJobPage({this.customerId, this.scheduledAt, super.key});

  /// The customer to start with, e.g. when opened from their page.
  final String? customerId;

  /// The visit's day and time to start with, e.g. an hour picked on the
  /// calendar.
  final DateTime? scheduledAt;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NewJobCubit(
        jobs: context.read(),
        customers: context.read(),
        speech: context.read(),
        customerId: customerId,
        scheduledAt: scheduledAt,
      )..start(),
      child: const NewJobView(),
    );
  }
}

class NewJobView extends StatefulWidget {
  const NewJobView({super.key});

  @override
  State<NewJobView> createState() => _NewJobViewState();
}

class _NewJobViewState extends State<NewJobView> {
  late final _description = TextEditingController(
    text: context.read<NewJobCubit>().state.description,
  );
  final _scroll = ScrollController();

  @override
  void dispose() {
    _description.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cubit = context.read<NewJobCubit>();
    await cubit.save();
    // The customer is the first step; bring it into view when missing.
    if (cubit.state.showsErrors &&
        cubit.state.customer == null &&
        _scroll.hasClients) {
      await _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _onSaved(NewJobState state) {
    final l10n = AppLocalizations.of(context);
    final job = state.saved!;
    final customer = state.customer!;
    final technician = switch (context.read<SessionCubit>().state) {
      SessionReady(:final profile) => profile.fullName,
      _ => '',
    };
    // This screen goes away; WhatsApp and its failure note belong to the
    // app, over the job's page.
    final app = Navigator.of(context, rootNavigator: true).context;
    context.pushReplacement(AppRoutes.job(job.id));
    if (state.sendsConfirmation) {
      unawaited(
        app.sendOnWhatsApp(
          confirmationMessage(
            l10n,
            job: job,
            customerName: customer.name,
            technicianName: technician,
            today: state.today,
          ),
          to: customer.phone,
        ),
      );
    }
  }

  void _onFailed(NewJobState state) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            commonFailureMessage(AppLocalizations.of(context), state.failure!),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<NewJobCubit>();
    final state = context.watch<NewJobCubit>().state;

    return MultiBlocListener(
      listeners: [
        BlocListener<NewJobCubit, NewJobState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: (context, state) {
            if (state.status == NewJobStatus.saved) _onSaved(state);
            if (state.status == NewJobStatus.failed) _onFailed(state);
          },
        ),
        BlocListener<NewJobCubit, NewJobState>(
          // Dictated words land in the field; typed ones are already there.
          listenWhen: (previous, current) =>
              current.description != _description.text,
          listener: (context, state) => _description.value = TextEditingValue(
            text: state.description,
            selection: TextSelection.collapsed(
              offset: state.description.length,
            ),
          ),
        ),
      ],
      child: Scaffold(
        appBar: const _Header(),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(16),
          children: [
            _Step(
              number: 1,
              title: l10n.newJobCustomerTitle,
              children: [_CustomerPicker(state: state)],
            ),
            const SizedBox(height: 22),
            _Step(
              number: 2,
              title: l10n.newJobProblemTitle,
              children: [
                TagChips(selected: state.tags, onToggle: cubit.toggleTag),
                _DescriptionField(
                  controller: _description,
                  onChanged: cubit.editDescription,
                ),
                _DictateButton(isListening: state.isListening),
              ],
            ),
            const SizedBox(height: 22),
            _Step(
              number: 3,
              title: l10n.newJobScheduleTitle,
              children: [
                SchedulePicker(
                  value: state.schedule,
                  today: state.today,
                  showsErrors: state.showsErrors,
                  onChanged: cubit.changeSchedule,
                ),
              ],
            ),
            if (state.canSendConfirmation) ...[
              const SizedBox(height: 22),
              _ConfirmationToggle(
                value: state.sendConfirmation,
                onChanged: (send) => cubit.setSendConfirmation(send: send),
              ),
            ],
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BusyFilledButton(
                label: l10n.newJobSave,
                isBusy:
                    state.status == NewJobStatus.saving ||
                    state.status == NewJobStatus.saved,
                onPressed: _save,
              ),
              const SizedBox(height: 6),
              Text(
                l10n.newJobSavedOffline,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: context.appColors.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The top bar: close, the title and how short the form is.
class _Header extends StatelessWidget implements PreferredSizeWidget {
  const _Header();

  @override
  Size get preferredSize => const Size.fromHeight(73);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Material(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 12, 16, 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  tooltip: l10n.newJobClose,
                  constraints: const BoxConstraints.tightFor(
                    width: 48,
                    height: 48,
                  ),
                  icon: Icon(Icons.close_rounded, color: colors.ink),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l10n.newJob,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        color: colors.ink,
                      ),
                    ),
                  ),
                ),
                Text(
                  l10n.newJobSteps,
                  style: TextStyle(fontSize: 13, color: colors.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One numbered part of the form.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.title,
    required this.children,
  });

  final int number;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.ink,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$number',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: colors.background,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
        for (final child in children) ...[const SizedBox(height: 10), child],
      ],
    );
  }
}

class _CustomerPicker extends StatelessWidget {
  const _CustomerPicker({required this.state});

  final NewJobState state;

  Future<void> _pick(BuildContext context) async {
    final cubit = context.read<NewJobCubit>();
    final customer = await showCustomerPicker(
      context,
      customers: state.customers ?? const [],
    );
    if (customer != null) cubit.selectCustomer(customer);
  }

  Future<void> _add(BuildContext context, String location) async {
    final cubit = context.read<NewJobCubit>();
    final customer = await context.push<Customer>(location);
    if (customer != null) cubit.selectCustomer(customer);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final customer = state.customer;
    final missing = state.showsErrors && customer == null;
    final hasCustomers = state.customers?.isNotEmpty ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (customer != null) ...[
          _ChosenCustomer(customer: customer, onChange: () => _pick(context)),
          const SizedBox(height: 10),
        ] else if (hasCustomers) ...[
          AppCard(
            radius: AppRadii.lg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            borderColor: missing ? colors.danger : colors.fieldBorder,
            onTap: () => _pick(context),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colors.inkSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.search_rounded, color: colors.ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.newJobPickCustomer,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.primary),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChipButton(
              label: l10n.newJobFromContacts,
              icon: Icons.person_outline_rounded,
              selected: false,
              onTap: () => _add(context, AppRoutes.newCustomerFromContacts),
            ),
            ChoiceChipButton(
              label: l10n.newJobNewCustomer,
              icon: Icons.add_rounded,
              selected: false,
              onTap: () => _add(context, AppRoutes.newCustomer),
            ),
          ],
        ),
        if (missing) ...[
          const SizedBox(height: 6),
          Text(
            l10n.newJobCustomerRequired,
            style: TextStyle(fontSize: 13, color: colors.danger),
          ),
        ],
      ],
    );
  }
}

class _ChosenCustomer extends StatelessWidget {
  const _ChosenCustomer({required this.customer, required this.onChange});

  final Customer customer;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final phone = customer.phone;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: colors.primary, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 4, 12),
        child: Row(
          children: [
            InitialsAvatar(name: customer.name, size: 44),
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
                    ),
                  ),
                  if (phone != null)
                    Text(
                      phone.local,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(fontSize: 14, color: colors.inkMuted),
                    ),
                ],
              ),
            ),
            TextButton(
              onPressed: onChange,
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              child: Text(l10n.newJobChangeCustomer),
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionField extends StatelessWidget {
  const _DescriptionField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  /// The counter shows only this close to the limit.
  static const int _counterFrom = Job.maxDescriptionLength - 100;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      minLines: 2,
      maxLines: 6,
      maxLength: Job.maxDescriptionLength,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 16, height: 1.6),
      buildCounter:
          (context, {required currentLength, required isFocused, maxLength}) =>
              currentLength >= _counterFrom
              ? Text('$currentLength/$maxLength')
              : null,
      decoration: InputDecoration(
        hintText: l10n.newJobDescriptionHint,
        hintStyle: TextStyle(fontSize: 16, color: context.appColors.inkMuted),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }
}

class _DictateButton extends StatelessWidget {
  const _DictateButton({required this.isListening});

  final bool isListening;

  Future<void> _toggle(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = AppLocalizations.of(context).newJobSpeechUnavailable;
    final listening = await context.read<NewJobCubit>().toggleListening();
    if (listening) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return DashedRRectBorder(
      color: colors.primary,
      radius: AppRadii.md,
      child: Material(
        color: isListening ? colors.primarySoft : colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: () => _toggle(context),
          child: SizedBox(
            height: 56,
            child: Semantics(
              liveRegion: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isListening ? Icons.stop_rounded : Icons.mic_none_rounded,
                    color: colors.primaryPressed,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      isListening ? l10n.newJobListening : l10n.newJobDictate,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.primaryPressed,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfirmationToggle extends StatelessWidget {
  const _ConfirmationToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Semantics(
      checked: value,
      child: AppCard(
        radius: AppRadii.lg,
        padding: const EdgeInsets.all(14),
        onTap: () => onChanged(!value),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: value ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(4),
                border: value
                    ? null
                    : Border.all(color: colors.fieldBorder, width: 1.5),
              ),
              child: value
                  ? Icon(Icons.check_rounded, size: 18, color: colors.onPrimary)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.newJobSendConfirmation,
                style: const TextStyle(fontSize: 15, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
