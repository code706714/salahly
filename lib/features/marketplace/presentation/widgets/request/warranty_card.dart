import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// After the work: a free warranty visit while it lasts, and asking the same
/// technician again.
class WarrantyCard extends StatelessWidget {
  const WarrantyCard({required this.details, super.key});

  final RequestDetails details;

  @override
  Widget build(BuildContext context) {
    final technician = details.chosenOffer?.technician;
    if (technician == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = context.watchHonorific();
    final name = firstNameOf(technician.name);
    final until = details.warrantyUntil;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (until != null) ...[
            Text(
              l10n.warrantyTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.warrantyBody(name, weekdayDate(until.toLocal())),
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: colors.inkMuted,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.push(
                AppRoutes.newRequestFor(
                  categoryId: details.categoryId,
                  technicianId: technician.id,
                  warrantyOf: details.id,
                ),
              ),
              child: Text(l10n.warrantyAsk),
            ),
            const SizedBox(height: 4),
          ],
          TextButton(
            onPressed: () => context.push(
              AppRoutes.newRequestFor(
                categoryId: details.categoryId,
                technicianId: technician.id,
              ),
            ),
            child: Text(l10n.myRequestsAgain(honorific, name)),
          ),
        ],
      ),
    );
  }
}
