import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/money_text.dart';
import 'package:salahly/core/widgets/whatsapp_button.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/cubit/quote_cubit.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/features/jobs/presentation/quote/quote_message.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_missing_view.dart';
import 'package:salahly/features/jobs/presentation/widgets/quote_add_item_sheet.dart';
import 'package:salahly/features/jobs/presentation/widgets/quote_item_row.dart';
import 'package:salahly/features/jobs/presentation/widgets/quote_preview.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A job's quote: its lines, total and how long it holds, with the
/// WhatsApp message the customer will get.
class QuotePage extends StatelessWidget {
  const QuotePage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = QuoteCubit(jobs: context.read(), jobId: jobId);
        unawaited(cubit.start());
        return cubit;
      },
      child: const QuoteView(),
    );
  }
}

class QuoteView extends StatelessWidget {
  const QuoteView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<QuoteCubit, QuoteState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              commonFailureMessage(
                AppLocalizations.of(context),
                state.failure!,
              ),
            ),
          ),
        ),
      child: BlocBuilder<QuoteCubit, QuoteState>(
        builder: (context, state) => switch (state.status) {
          JobDetailsStatus.loading => const Scaffold(),
          JobDetailsStatus.ready => _QuoteScreen(state: state),
          JobDetailsStatus.missing ||
          JobDetailsStatus.deleted => JobMissingView(
            title: AppLocalizations.of(context).quoteTitle,
          ),
        },
      ),
    );
  }
}

class _QuoteScreen extends StatelessWidget {
  const _QuoteScreen({required this.state});

  final QuoteState state;

  @override
  Widget build(BuildContext context) {
    final profile = context.select<SessionCubit, UserProfile?>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile,
        _ => null,
      },
    );
    // Briefly null while signing out, before the redirect.
    if (profile == null) return const Scaffold();
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<QuoteCubit>();
    final details = state.details!;
    final job = details.job;
    final customer = details.customer;
    final hasItems = state.items.isNotEmpty;
    final isPlatform = job.source == JobSource.platform;
    final message = quoteMessage(
      l10n,
      customerName: customer.name,
      items: state.items,
      validDays: state.validDays,
      toBook: job.status == JobStatus.unconfirmed,
      technicianName: profile.fullName,
      technicianPhone: PhoneNumber.tryParse(profile.phone),
    );

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard(context)) navigator.pop();
      },
      child: Scaffold(
        appBar: DetailHeader(
          title: l10n.quoteTitle,
          subtitle: '${customer.name} · ${jobTitle(l10n, job)}',
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (job.quoteStatus
                case QuoteStatus.sent ||
                    QuoteStatus.accepted ||
                    QuoteStatus.declined) ...[
              _ReplyNotice(
                status: job.quoteStatus,
                // Only the consumer answers a platform job's quote.
                canMarkAccepted: !isPlatform,
                onAccepted: state.isSaving ? null : cubit.markAccepted,
              ),
              const SizedBox(height: 14),
            ],
            _ItemsCard(state: state),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.quoteTotal,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        // A price change in the app waits for its answer.
                        if (!isPlatform) _ValidityButton(days: state.validDays),
                      ],
                    ),
                  ),
                  MoneyText(
                    state.totalPiastres,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (isPlatform) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(
                    Icons.smartphone_outlined,
                    size: 20,
                    color: colors.inkMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.platformJobQuoteInApp,
                      style: TextStyle(fontSize: 14, color: colors.inkMuted),
                    ),
                  ),
                ],
              ),
            ] else if (hasItems) ...[
              const SizedBox(height: 14),
              Text(
                l10n.quotePreviewTitle,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              QuotePreview(message: message, sentAt: DateTime.now()),
            ],
          ],
        ),
        bottomNavigationBar: BottomActionBar(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isPlatform)
                FilledButton(
                  onPressed: hasItems && !state.isSaving
                      ? () => _sendInApp(context)
                      : null,
                  child: Text(l10n.platformJobQuoteSend),
                )
              else
                Opacity(
                  opacity: hasItems ? 1 : 0.5,
                  child: WhatsAppButton(
                    label: l10n.quoteSend,
                    size: WhatsAppButtonSize.large,
                    onPressed: hasItems && !state.isSaving
                        ? () => _send(context, message, customer.phone)
                        : null,
                  ),
                ),
              const SizedBox(height: 6),
              TextButton(
                onPressed: state.isSaving ? null : () => _saveDraft(context),
                style: TextButton.styleFrom(foregroundColor: colors.inkMuted),
                child: Text(l10n.quoteSaveDraft),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send(
    BuildContext context,
    String message,
    PhoneNumber? phone,
  ) async {
    final note = AppLocalizations.of(context).quoteSavedNote;
    final sent = await context.read<QuoteCubit>().send();
    if (!sent || !context.mounted) return;
    await context.sendOnWhatsApp(message, to: phone, failureNote: note);
  }

  /// Sends a platform job's quote to the consumer, who answers it in the
  /// app, and goes back to the job.
  Future<void> _sendInApp(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (await context.read<QuoteCubit>().send()) navigator.pop();
  }

  Future<void> _saveDraft(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (await context.read<QuoteCubit>().saveDraft()) navigator.pop();
  }

  Future<bool> _confirmDiscard(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.quoteDiscardTitle),
        content: Text(l10n.quoteDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.quoteStay),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.danger,
            ),
            child: Text(l10n.quoteDiscard),
          ),
        ],
      ),
    );
    return discard ?? false;
  }
}

/// Where the sent quote stands: waiting for the customer, with a way to
/// record their yes when [canMarkAccepted], accepted, or declined.
class _ReplyNotice extends StatelessWidget {
  const _ReplyNotice({
    required this.status,
    required this.canMarkAccepted,
    required this.onAccepted,
  });

  /// Sent, accepted or declined.
  final QuoteStatus status;
  final bool canMarkAccepted;
  final VoidCallback? onAccepted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final (background, foreground, icon, text) = switch (status) {
      QuoteStatus.accepted => (
        colors.successSoft,
        colors.success,
        Icons.check_circle_outline_rounded,
        l10n.quoteAccepted,
      ),
      QuoteStatus.declined => (
        colors.dangerSoft,
        colors.dangerDeep,
        Icons.cancel_outlined,
        l10n.platformJobQuoteDeclined,
      ),
      _ => (
        colors.warningSoft,
        colors.warning,
        Icons.schedule,
        l10n.jobQuoteSent,
      ),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                  if (status == QuoteStatus.declined)
                    Text(
                      l10n.platformJobQuoteDeclinedHint,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: foreground,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (status == QuoteStatus.sent && canMarkAccepted)
            TextButton(
              onPressed: onAccepted,
              style: TextButton.styleFrom(foregroundColor: colors.primary),
              child: Text(l10n.quoteMarkAccepted),
            ),
        ],
      ),
    );
  }
}

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({required this.state});

  final QuoteState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<QuoteCubit>();
    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        side: BorderSide(color: colors.border, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (state.items.isEmpty)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: colors.divider)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  l10n.quoteEmpty,
                  style: TextStyle(fontSize: 15, color: colors.inkMuted),
                ),
              ),
            ),
          for (final (index, item) in state.items.indexed)
            QuoteItemRow(
              item: item,
              onIncrement: () => cubit.increment(index),
              onDecrement: () => cubit.decrement(index),
              onRemove: () => cubit.remove(index),
            ),
          InkWell(
            onTap: () => _addItem(context),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_rounded, size: 22, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    l10n.quoteAddItem,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addItem(BuildContext context) async {
    final cubit = context.read<QuoteCubit>();
    final item = await showQuoteAddItemSheet(
      context,
      suggestions: state.suggestions,
    );
    if (item != null) cubit.addItem(item);
  }
}

/// "العرض ساري 3 أيام"; tapping it picks another length.
class _ValidityButton extends StatelessWidget {
  const _ValidityButton({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return TextButton(
      onPressed: () => _pick(context),
      style: TextButton.styleFrom(
        foregroundColor: colors.inkMuted,
        padding: EdgeInsets.zero,
        alignment: AlignmentDirectional.centerStart,
        textStyle: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l10n.quoteValidFor(days)),
          const SizedBox(width: 2),
          const Icon(Icons.expand_more_rounded, size: 18),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<QuoteCubit>();
    final picked = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.quoteValidityTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final choice in QuoteCubit.validityChoices)
                    ChoiceChipButton(
                      label: l10n.quoteValidityDays(choice),
                      selected: choice == days,
                      minHeight: 48,
                      onTap: () => Navigator.of(context).pop(choice),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked != null) cubit.setValidDays(picked);
  }
}
