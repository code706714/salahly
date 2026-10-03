import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/core/widgets/whatsapp_button.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/presentation/cubit/invoice_cubit.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_labels.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_message.dart';
import 'package:salahly/features/jobs/presentation/widgets/invoice_card.dart';
import 'package:salahly/features/jobs/presentation/widgets/invoice_promise_card.dart';
import 'package:salahly/features/jobs/presentation/widgets/invoice_record_card.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_card_label.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_missing_view.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A job's invoice: what it comes to, the money received, recording more
/// of it and sending the invoice to the customer.
class InvoicePage extends StatelessWidget {
  const InvoicePage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => InvoiceCubit(
        jobs: context.read(),
        apps: context.read(),
        sharedFiles: context.read(),
        jobId: jobId,
      )..start(),
      child: const InvoiceView(),
    );
  }
}

class InvoiceView extends StatelessWidget {
  const InvoiceView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<InvoiceCubit, InvoiceState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) {
        final l10n = AppLocalizations.of(context);
        final failure = state.failure!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                failure is InvoicePdfFailure
                    ? l10n.invoicePdfFailed
                    : commonFailureMessage(l10n, failure),
              ),
            ),
          );
      },
      child: BlocBuilder<InvoiceCubit, InvoiceState>(
        builder: (context, state) {
          final profile = context.select<SessionCubit, UserProfile?>(
            (cubit) => switch (cubit.state) {
              SessionReady(:final profile) => profile,
              _ => null,
            },
          );
          final details = state.details;
          // The profile is briefly null while signing out.
          if (state.status == JobDetailsStatus.loading || profile == null) {
            return const Scaffold();
          }
          if (details == null) {
            return JobMissingView(
              title: AppLocalizations.of(context).invoiceTitleUnnumbered,
            );
          }
          return _InvoiceScreen(
            state: state,
            details: details,
            profile: profile,
          );
        },
      ),
    );
  }
}

class _InvoiceScreen extends StatefulWidget {
  const _InvoiceScreen({
    required this.state,
    required this.details,
    required this.profile,
  });

  final InvoiceState state;
  final JobDetails details;
  final UserProfile profile;

  @override
  State<_InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<_InvoiceScreen> {
  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  bool _isFullAmount = true;
  PaymentMethod _method = PaymentMethod.cash;

  int get _balance => widget.details.balancePiastres;

  /// The amount to record, or null when what is typed is not a number.
  int? get _amountPiastres =>
      _isFullAmount ? _balance : parsePounds(_amount.text);

  @override
  void initState() {
    super.initState();
    _amount.text = formatPounds(_balance);
  }

  @override
  void didUpdateWidget(_InvoiceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isFullAmount && oldWidget.details.balancePiastres != _balance) {
      _amount.text = formatPounds(_balance);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _onFullAmount() {
    _amountFocus.unfocus();
    setState(() {
      _isFullAmount = true;
      _amount.text = formatPounds(_balance);
    });
  }

  void _onPartAmount() {
    setState(() {
      _isFullAmount = false;
      _amount.clear();
    });
    _amountFocus.requestFocus();
  }

  void _onAmountChanged(String text) =>
      setState(() => _isFullAmount = parsePounds(text) == _balance);

  Future<void> _record(int amount) async {
    _amountFocus.unfocus();
    await context.read<InvoiceCubit>().recordPayment(
      amountPiastres: amount,
      method: _method,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final state = widget.state;
    final details = widget.details;
    final job = details.job;
    final customer = details.customer;
    final technicianPhone = PhoneNumber.tryParse(widget.profile.phone);
    final technicianName = widget.profile.fullName;
    final number = job.invoiceNumber;
    final needsPrice = details.totalPiastres == 0;
    final balance = _balance;
    final recorded = state.recorded;
    final records = !needsPrice && balance > 0 && recorded == null;
    final amount = _amountPiastres;
    final amountTooHigh = amount != null && amount > balance;
    final toRecord = amount != null && amount >= 1 && !amountTooHigh
        ? amount
        : null;
    final fromQuote =
        job.quoteStatus == QuoteStatus.sent ||
        job.quoteStatus == QuoteStatus.accepted;
    final areaName = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(customer.areaId),
    );
    final place = [?details.address, ?areaName].join('، ');

    return Scaffold(
      appBar: DetailHeader(
        title: number == null
            ? l10n.invoiceTitleUnnumbered
            : l10n.invoiceTitle(invoiceNumberLabel(number)),
        subtitle: [
          customer.name,
          if (fromQuote) l10n.invoiceFromQuote,
        ].join(' · '),
        trailing: needsPrice
            ? null
            : _PdfButton(
                isSharing: state.isSharing,
                onPressed: () => context.read<InvoiceCubit>().sharePdf(
                  l10n,
                  technicianName: technicianName,
                  technicianPhone: technicianPhone,
                  place: place.isEmpty ? null : place,
                ),
              ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (needsPrice)
            AppCard(
              child: Text(
                l10n.invoiceNeedsPrice,
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
            )
          else
            InvoiceCard(
              details: details,
              technicianName: technicianName,
              technicianPhone: technicianPhone,
              issuedOn: job.finishedAt ?? state.today,
            ),
          if (details.payments.isNotEmpty) ...[
            const SizedBox(height: 14),
            _PaymentsCard(payments: details.payments),
          ],
          if (records) ...[
            const SizedBox(height: 14),
            InvoiceRecordCard(
              amount: _amount,
              amountFocus: _amountFocus,
              isFullAmount: _isFullAmount,
              method: _method,
              onFullAmount: _onFullAmount,
              onPartAmount: _onPartAmount,
              onAmountChanged: _onAmountChanged,
              onMethod: (method) => setState(() => _method = method),
              errorText: amountTooHigh
                  ? l10n.invoiceAmountTooHigh(formatPounds(balance))
                  : null,
            ),
          ],
          if (recorded != null) ...[
            const SizedBox(height: 14),
            _DoneBanner(
              text: recorded.balancePiastres == 0
                  ? l10n.invoiceRecordedAll(
                      paymentMethodLabel(l10n, recorded.method),
                    )
                  : l10n.invoiceRecordedPart(
                      formatPounds(recorded.amountPiastres),
                      paymentMethodLabel(l10n, recorded.method),
                      formatPounds(recorded.balancePiastres),
                    ),
            ),
          ] else if (!needsPrice && balance == 0) ...[
            const SizedBox(height: 14),
            _DoneBanner(text: l10n.invoiceSettled),
          ],
          if (job.status == JobStatus.finished && balance > 0) ...[
            const SizedBox(height: 14),
            InvoicePromiseCard(
              promisedOn: job.paymentPromisedOn,
              today: state.today,
              onPick: () => _pickPromise(job.paymentPromisedOn),
              onClear: () =>
                  context.read<InvoiceCubit>().setPaymentPromise(null),
            ),
          ],
          if (!needsPrice) ...[
            const SizedBox(height: 14),
            WhatsAppButton(
              label: l10n.invoiceSend,
              onPressed: () => context.sendOnWhatsApp(
                invoiceMessage(
                  l10n,
                  details: details,
                  technicianName: technicianName,
                  technicianPhone: technicianPhone,
                ),
                to: customer.phone,
              ),
            ),
          ],
        ],
      ),
      bottomNavigationBar: BottomActionBar(
        child: needsPrice
            ? FilledButton(
                onPressed: () => context.push(AppRoutes.jobQuote(job.id)),
                child: Text(l10n.invoiceWriteQuote),
              )
            : records
            ? BusyFilledButton(
                label: toRecord == null
                    ? l10n.invoiceRecordEmpty
                    : l10n.invoiceRecord(formatPounds(toRecord)),
                isBusy: state.isRecording,
                onPressed: toRecord == null ? null : () => _record(toRecord),
              )
            : const _SeeMoneyButton(),
      ),
    );
  }

  Future<void> _pickPromise(DateTime? current) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<InvoiceCubit>();
    final today = CalendarDate.of(widget.state.today);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isBefore(today)
          ? current
          : tomorrow,
      firstDate: today,
      lastDate: DateTime(today.year, today.month, today.day + 90),
      helpText: l10n.invoicePromiseTitle,
    );
    if (picked != null) await cubit.setPaymentPromise(picked);
  }
}

class _PdfButton extends StatelessWidget {
  const _PdfButton({required this.isSharing, required this.onPressed});

  final bool isSharing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (isSharing) {
      return const SizedBox.square(
        dimension: 48,
        child: Center(
          child: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: context.appColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(AppLocalizations.of(context).invoicePdf),
    );
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({required this.payments});

  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JobCardLabel(l10n.invoicePayments),
          for (final payment in payments) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.invoicePaymentLine(
                      paymentMethodLabel(l10n, payment.method),
                      weekdayDate(payment.receivedAt),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.pounds(formatPounds(payment.amountPiastres)),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DoneBanner extends StatelessWidget {
  const _DoneBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: colors.successSoft,
          borderRadius: BorderRadius.circular(AppRadii.lg),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: colors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.6,
                  color: colors.success,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SeeMoneyButton extends StatelessWidget {
  const _SeeMoneyButton();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return FilledButton(
      onPressed: () => context.go(AppRoutes.technicianMoney),
      style: FilledButton.styleFrom(
        backgroundColor: colors.inkSoft,
        foregroundColor: colors.ink,
      ),
      child: Text(AppLocalizations.of(context).invoiceSeeMoney),
    );
  }
}
