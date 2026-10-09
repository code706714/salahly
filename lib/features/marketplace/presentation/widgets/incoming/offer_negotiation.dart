import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/text/money.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/busy_filled_button.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/offer_thread_sheet.dart';
import 'package:salahly/features/marketplace/presentation/widgets/price_dialog.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/confirm_choice_dialog.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What the technician can do about the price of the offer they sent while
/// the consumer hasn't picked yet: take the price the consumer asked for,
/// lower their own, take the offer back, or read the talk so far.
class OfferNegotiation extends StatelessWidget {
  const OfferNegotiation({required this.offer, super.key});

  final MyOffer offer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final busy = context.select<OfferCubit, OfferAction?>(
      (cubit) => cubit.state.busy,
    );
    final counter = offer.counterPricePiastres;
    final range = offer.reviseRange;
    final idle = busy == null;
    return AppCard(
      borderColor: offer.isCountered ? colors.warning : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (offer.isCountered && counter != null) ...[
            Text(
              l10n.negCounterTitle(l10n.pounds(formatPounds(counter))),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.negCounterBody,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: colors.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
            BusyFilledButton(
              label: l10n.negAccept(l10n.pounds(formatPounds(counter))),
              isBusy: busy == OfferAction.acceptCounter,
              onPressed: idle ? () => _accept(context, counter) : null,
            ),
            const SizedBox(height: 8),
          ],
          if (range != null)
            OutlinedButton(
              onPressed: idle ? () => _revise(context, range) : null,
              style: _outlined(colors),
              child: Text(l10n.negRevise),
            ),
          if (range != null && !offer.isCountered)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                l10n.negRevisionsLeft(offer.revisionsLeft),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.inkMuted),
              ),
            ),
          Row(
            children: [
              TextButton(
                onPressed: idle ? () => _withdraw(context) : null,
                style: TextButton.styleFrom(foregroundColor: colors.danger),
                child: Text(l10n.negWithdraw),
              ),
              const Spacer(),
              if (offer.isCountered ||
                  offer.revisionsLeft < MyOffer.maxRevisions)
                TextButton(
                  onPressed: () => _showThread(context),
                  child: Text(l10n.offersThread),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static ButtonStyle _outlined(AppColors colors) => OutlinedButton.styleFrom(
    foregroundColor: colors.ink,
    minimumSize: const Size.fromHeight(48),
    side: BorderSide(color: colors.fieldBorder, width: 1.5),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.md),
    ),
  );

  Future<void> _accept(BuildContext context, int counter) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<OfferCubit>();
    final confirmed = await showConfirmChoiceDialog(
      context,
      title: l10n.negAcceptTitle(l10n.pounds(formatPounds(counter))),
      body: l10n.negAcceptBody,
      keep: l10n.negKeep,
      confirm: l10n.negAcceptConfirm,
    );
    if (confirmed) await cubit.acceptCounter();
  }

  Future<void> _revise(BuildContext context, ({int min, int max}) range) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<OfferCubit>();
    final price = await showPriceDialog(
      context,
      title: l10n.negReviseTitle,
      body: l10n.negReviseBody(
        l10n.pounds(formatPounds(offer.pricePiastres)),
        offer.revisionsLeft,
      ),
      confirm: l10n.negReviseConfirm,
      range: range,
    );
    if (price != null) await cubit.reviseOffer(price);
  }

  Future<void> _withdraw(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<OfferCubit>();
    final confirmed = await showConfirmChoiceDialog(
      context,
      title: l10n.negWithdrawTitle,
      body: l10n.negWithdrawBody,
      keep: l10n.negKeep,
      confirm: l10n.negWithdrawConfirm,
      destructive: true,
    );
    if (confirmed) await cubit.withdrawOffer();
  }

  Future<void> _showThread(BuildContext context) {
    final requests = context.read<TechnicianRequestsRepository>();
    return showOfferThreadSheet(
      context,
      fetch: () => requests.fetchOfferThread(offer.id),
      viewer: UserRole.technician,
    );
  }
}
