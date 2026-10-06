import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/money_text.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/standing_pill.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The offer the technician sent on [request], read-only, with where it
/// stands: waiting for the consumer, picked, or not.
class SentOfferCard extends StatelessWidget {
  const SentOfferCard({
    required this.request,
    required this.offer,
    required this.now,
    super.key,
  });

  final IncomingRequest request;
  final MyOffer offer;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final standing = standingOf(request);
    final serviceName = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.serviceName(offer.serviceId),
    );
    final note = offer.note;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.offerFormTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: standing == IncomingStanding.offerSent
                    ? StatusPill(
                        label: l10n.offerFormWaiting(
                          request.consumerHonorific.name,
                        ),
                        tone: PillTone.waiting,
                        icon: Icons.schedule_rounded,
                      )
                    : StandingPill(request: request, standing: standing),
              ),
            ],
          ),
          const SizedBox(height: 10),
          MoneyText(
            offer.pricePiastres,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
          ),
          if (serviceName != null)
            Text(
              serviceName,
              style: TextStyle(fontSize: 14, color: colors.inkMuted),
            ),
          const SizedBox(height: 6),
          Text(
            arrivalLabel(l10n, offer.arriveAt, today: now),
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
          if (note != null) ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  note,
                  style: const TextStyle(fontSize: 15, height: 1.6),
                ),
              ),
            ),
          ],
          if (standing == IncomingStanding.chosen) ...[
            const SizedBox(height: 10),
            Text(
              l10n.offerFormChosenHint,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.success,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
