import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/bottom_action_bar.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/balance/presentation/balance_navigation.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/jobs/presentation/widgets/pounds_field.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_cubit.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/incoming_request_details.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/sent_offer_card.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One new request for the technician, and sending an offer on it.
class IncomingRequestPage extends StatelessWidget {
  const IncomingRequestPage({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = OfferCubit(
          requests: context.read(),
          requestId: requestId,
        );
        unawaited(cubit.start());
        return cubit;
      },
      child: BlocListener<OfferCubit, OfferState>(
        // The requests list shows where this request stands too.
        listenWhen: (previous, current) =>
            current.request != null && previous.request != current.request,
        listener: (context, state) =>
            context.read<IncomingRequestsCubit>().updateRequest(state.request!),
        child: const IncomingRequestView(),
      ),
    );
  }
}

class IncomingRequestView extends StatelessWidget {
  const IncomingRequestView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<OfferCubit, OfferState>(
      listenWhen: (previous, current) =>
          previous.failure != current.failure && current.failure != null,
      listener: (context, state) {
        final failure = state.failure!;
        // The free jobs left may have run out since the profile was read.
        if (failure is NoCreditsFailure) {
          unawaited(context.read<SessionCubit>().refreshProfile());
        }
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                technicianOfferFailureMessage(
                  AppLocalizations.of(context),
                  failure,
                ),
              ),
            ),
          );
      },
      child: BlocBuilder<OfferCubit, OfferState>(
        builder: (context, state) {
          final request = state.request;
          if (request != null) {
            return _RequestScreen(request: request, state: state);
          }
          return switch (state.status) {
            OfferLoadStatus.loading => const _Loading(),
            OfferLoadStatus.missing ||
            OfferLoadStatus.ready => const _Unavailable(missing: true),
            OfferLoadStatus.failed => const _Unavailable(missing: false),
          };
        },
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DetailHeader(
        title: AppLocalizations.of(context).incomingRequestTitle,
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

/// A request that couldn't be shown: not sent to this technician, or not
/// fetched yet ([missing] false), with a retry.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.missing});

  final bool missing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: DetailHeader(title: l10n.incomingRequestTitle),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                missing ? l10n.marketplaceNotFound : l10n.requestLoadFailed,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.appColors.inkMuted,
                ),
              ),
              if (!missing) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: context.read<OfferCubit>().fetchRequest,
                  child: Text(l10n.retry),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The request, and below it the offer: the form while the request takes
/// one, else the offer sent or why none can be sent.
class _RequestScreen extends StatefulWidget {
  const _RequestScreen({required this.request, required this.state});

  final IncomingRequest request;
  final OfferState state;

  @override
  State<_RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<_RequestScreen> {
  final _price = TextEditingController();
  final _note = TextEditingController();

  /// The service chip the price came from.
  String? _serviceId;
  late DateTime? _arriveAt = widget.state.arrivalChoices.firstOrNull;

  @override
  void initState() {
    super.initState();
    _price.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _price.dispose();
    _note.dispose();
    super.dispose();
  }

  void _onPriceChanged() => setState(() {});

  /// The typed price, when it is one an offer can have.
  int? get _pricePiastres {
    final price = parsePounds(_price.text);
    return price != null && price >= 100 ? price : null;
  }

  void _pickService(_ServiceChoice choice) {
    setState(() => _serviceId = choice.serviceId);
    _price.text = formatPounds(choice.pounds * 100);
  }

  Future<void> _send(int price, DateTime arriveAt) async {
    FocusScope.of(context).unfocus();
    final note = _note.text.trim();
    await context.read<OfferCubit>().sendOffer(
      OfferDraft(
        serviceId: _serviceId,
        pricePiastres: price,
        arriveAt: arriveAt,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  Future<void> _dismiss() async {
    final l10n = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final cubit = context.read<OfferCubit>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.offerFormDismissTitle),
        content: Text(l10n.offerFormDismissBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.offerFormDismissKeep),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.primary,
            ),
            child: Text(l10n.offerFormDismissConfirm),
          ),
        ],
      ),
    );
    if (!(confirmed ?? false)) return;
    if (await cubit.dismissRequest()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final request = widget.request;
    final state = widget.state;
    final standing = standingOf(request);
    final offer = request.myOffer;
    final credits = context.select<SessionCubit, int>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile.technician?.jobCredits ?? 0,
        _ => 0,
      },
    );
    final waiting = context.select<IncomingRequestsCubit, int>(
      (cubit) => cubit.state.pendingOffers,
    );
    final choices = state.arrivalChoices;
    final notice = switch (standing) {
      IncomingStanding.open when credits == 0 => l10n.technicianNoCredits,
      IncomingStanding.open when waiting >= credits =>
        l10n.technicianOffersWaiting,
      IncomingStanding.open when choices.isEmpty => l10n.offerFormNoTimes,
      IncomingStanding.open => null,
      _ when offer != null => null,
      _ => standingLabel(l10n, request, standing),
    };
    final takesOffer = standing == IncomingStanding.open && notice == null;
    final arriveAt = choices.contains(_arriveAt) ? _arriveAt : null;
    final price = _pricePiastres;

    return Scaffold(
      appBar: DetailHeader(title: l10n.incomingRequestTitle),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          IncomingRequestDetails(
            request: request,
            photoUrls: state.photoUrls,
            now: state.now,
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 18,
                  color: colors.inkMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.incomingSentTo(request.sentTo, request.offerCount),
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: colors.inkMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (offer != null)
            SentOfferCard(request: request, offer: offer, now: state.now)
          else if (notice != null)
            _Notice(
              text: notice,
              action: credits == 0 && standing == IncomingStanding.open
                  ? (
                      label: l10n.buyUsesTitleTechnician,
                      onTap: () => context.openBuyUses(UserRole.technician),
                    )
                  : null,
            )
          else
            _OfferForm(
              request: request,
              services: state.services,
              price: _price,
              note: _note,
              serviceId: _serviceId,
              onService: _pickService,
              choices: choices,
              arriveAt: arriveAt,
              onArrival: (at) => setState(() => _arriveAt = at),
              today: state.now,
            ),
        ],
      ),
      bottomNavigationBar: standing == IncomingStanding.open
          ? BottomActionBar(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (takesOffer) ...[
                    BusyFilledButton(
                      label: price == null
                          ? l10n.offerFormSendEmpty
                          : l10n.offerFormSend(formatPounds(price)),
                      isBusy: state.busy == OfferAction.send,
                      onPressed:
                          price == null ||
                              arriveAt == null ||
                              state.busy != null
                          ? null
                          : () => _send(price, arriveAt),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextButton(
                    onPressed: state.busy == null ? _dismiss : null,
                    child: Text(l10n.offerFormDismiss),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

/// A service the technician offers in the request's category, as a price
/// chip: "كشف وتنظيف 350".
final class _ServiceChoice {
  const _ServiceChoice({
    required this.serviceId,
    required this.name,
    required this.pounds,
  });

  final String serviceId;
  final String name;

  /// The starting price in whole pounds.
  final int pounds;
}

class _OfferForm extends StatelessWidget {
  const _OfferForm({
    required this.request,
    required this.services,
    required this.price,
    required this.note,
    required this.serviceId,
    required this.onService,
    required this.choices,
    required this.arriveAt,
    required this.onArrival,
    required this.today,
  });

  final IncomingRequest request;
  final List<ServicePrice> services;
  final TextEditingController price;
  final TextEditingController note;
  final String? serviceId;
  final ValueChanged<_ServiceChoice> onService;
  final List<DateTime> choices;
  final DateTime? arriveAt;
  final ValueChanged<DateTime> onArrival;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final category = context.select<CategoriesCubit, ServiceCategory?>(
      (cubit) => cubit.state.category(request.categoryId),
    );
    // Only services of the request's category can go with its offer.
    final serviceChoices = [
      for (final service in services)
        if (category?.services
                .where((known) => known.id == service.serviceId)
                .firstOrNull
            case final known?)
          _ServiceChoice(
            serviceId: service.serviceId,
            name: known.name,
            pounds: service.startingPricePiastres ~/ 100,
          ),
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.offerFormTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          _Label(l10n.offerFormPrice),
          const SizedBox(height: 8),
          PoundsField(
            controller: price,
            fontSize: 26,
            maxDigits: 6,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 9,
            ),
          ),
          if (serviceChoices.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final choice in serviceChoices)
                  ChoiceChipButton(
                    label: l10n.offerFormServiceChip(
                      choice.name,
                      formatPounds(choice.pounds * 100),
                    ),
                    selected: choice.serviceId == serviceId,
                    onTap: () => onService(choice),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          _Label(l10n.offerFormArrival),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final at in choices)
                ChoiceChipButton(
                  label: arrivalChoiceLabel(l10n, at, today: today),
                  selected: at == arriveAt,
                  onTap: () => onArrival(at),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _Label(l10n.offerFormNote(request.consumerHonorific.name)),
          const SizedBox(height: 8),
          TextField(
            controller: note,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(300)],
            style: const TextStyle(fontSize: 15, height: 1.6),
            decoration: InputDecoration(
              hintText: l10n.offerFormNoteHint,
              hintStyle: TextStyle(
                fontSize: 15,
                color: context.appColors.inkMuted,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );
  }
}

/// Why no offer can be sent: the request closed, no free jobs are left, or
/// its time is over.
class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action});

  final String text;

  /// A button under the text, e.g. to buy more uses.
  final ({String label, VoidCallback onTap})? action;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.warningSoft,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline_rounded, size: 20, color: colors.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.6,
                      color: colors.warning,
                    ),
                  ),
                  if (action case (:final label, :final onTap))
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: FilledButton(
                        onPressed: onTap,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(label),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
