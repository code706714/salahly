import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/launch/launch_feedback.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/initials_avatar.dart';
import 'package:salahly/core/widgets/square_icon_button.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/presentation/widgets/job_card_label.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Who the job is for and where: call, WhatsApp and the map, each shown
/// only when the customer has what it needs.
class JobCustomerCard extends StatelessWidget {
  const JobCustomerCard({required this.details, super.key});

  final JobDetails details;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final customer = details.customer;
    final phone = customer.phone;
    final areaName = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(customer.areaId),
    );
    final place = [?details.address, ?areaName].join('، ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JobCardLabel(l10n.jobPageCustomer),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  onTap: () => context.push(AppRoutes.customer(customer.id)),
                  child: Row(
                    children: [
                      InitialsAvatar(name: customer.name),
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
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (phone != null)
                              Text(
                                phone.local,
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: colors.inkMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (phone != null) ...[
                const SizedBox(width: 12),
                SquareIconButton(
                  icon: Icons.phone_outlined,
                  tooltip: l10n.jobPageCall,
                  background: colors.inkSoft,
                  onPressed: () => context.dial(phone),
                ),
                const SizedBox(width: 12),
                SquareIconButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  tooltip: l10n.jobPageWhatsapp,
                  background: colors.whatsapp,
                  foreground: colors.onWhatsapp,
                  onPressed: () => context.sendOnWhatsApp(
                    l10n.jobPageGreeting(customer.name),
                    to: phone,
                  ),
                ),
              ],
            ],
          ),
          if (place.isNotEmpty) ...[
            const SizedBox(height: 10),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.divider)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 13),
                    child: Icon(
                      Icons.place_outlined,
                      size: 22,
                      color: colors.inkMuted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        place,
                        style: const TextStyle(fontSize: 15, height: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: () => context.openMap(place),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.primary,
                      minimumSize: const Size(48, 48),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      textStyle: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: Text(l10n.jobPageMap),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
