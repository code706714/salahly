import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/request_issue_badge.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/request_photos.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What the consumer asked for, as far as a technician may see before
/// being picked: the problem, their first name, photos, the area and the
/// time, never the address or phone number.
class IncomingRequestDetails extends StatelessWidget {
  const IncomingRequestDetails({
    required this.request,
    required this.photoUrls,
    required this.now,
    super.key,
  });

  final IncomingRequest request;

  /// Links to the photos, by path.
  final Map<String, String> photoUrls;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final honorific = request.consumerHonorific.name;
    final category = context.select<CategoriesCubit, String?>(
      (cubit) => cubit.state.category(request.categoryId)?.name,
    );
    final areaName = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(request.areaId),
    );
    final description = request.description;
    final place = [
      ?areaName,
      distanceLabel(l10n, request.distanceKm),
    ].join(' · ');

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              RequestIssueBadge(issue: request.issue),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incomingTitle(l10n, request, category: category),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    Text(
                      [
                        sentAgoLabel(l10n, request.createdAt, now: now),
                        l10n.incomingConsumer(honorific, request.consumerName),
                      ].join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 12),
            Text(
              description,
              style: const TextStyle(fontSize: 16, height: 1.7),
            ),
          ],
          if (request.photoPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            RequestPhotos(paths: request.photoPaths, urls: photoUrls),
          ],
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Fact(icon: Icons.place_outlined, text: place),
                  const SizedBox(height: 8),
                  _Fact(
                    icon: Icons.calendar_today_outlined,
                    text: requestDayLabel(
                      l10n,
                      request.day,
                      request.window,
                      today: now,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.incomingPrivacy(honorific),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: colors.inkMuted,
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
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: context.appColors.inkMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 15, height: 1.6)),
        ),
      ],
    );
  }
}
