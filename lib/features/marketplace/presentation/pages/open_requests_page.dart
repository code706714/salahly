import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/category_icon.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/home/presentation/widgets/verification_banner.dart';
import 'package:salahly/features/marketplace/presentation/cubit/open_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/incoming_request_card.dart';
import 'package:salahly/features/marketplace/presentation/widgets/load_failed_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The "طلبات متاحة" tab: every open request in the technician's trades and
/// areas, to open and answer with an offer. Verified technicians only.
class OpenRequestsPage extends StatelessWidget {
  const OpenRequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final status = context.select<SessionCubit, VerificationStatus?>(
      (cubit) => switch (cubit.state) {
        SessionReady(:final profile) => profile.technician?.verificationStatus,
        _ => null,
      },
    );
    if (status != VerificationStatus.approved) {
      return _Locked(status: status);
    }
    return BlocProvider(
      create: (context) {
        final cubit = OpenRequestsCubit(context.read());
        unawaited(cubit.load());
        return cubit;
      },
      child: const OpenRequestsView(),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        AppLocalizations.of(context).openRequestsTitle,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// A technician whose documents are not approved sees why the list is
/// empty, not an empty list.
class _Locked extends StatelessWidget {
  const _Locked({required this.status});

  final VerificationStatus? status;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            const _Title(),
            VerificationBanner(
              status: status,
              padding: const EdgeInsets.only(top: 16),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.openRequestsLocked,
              style: TextStyle(
                fontSize: 15,
                height: 1.7,
                color: context.appColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OpenRequestsView extends StatelessWidget {
  const OpenRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<OpenRequestsCubit>();
    final state = context.watch<OpenRequestsCubit>().state;
    final now = DateTime.now();
    final categories = [
      for (final category in context.watch<CategoriesCubit>().state.categories)
        if (category.isActive) category,
    ];
    return Scaffold(
      body: SafeArea(
        child: switch (state.status) {
          OpenRequestsStatus.failed => Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _Title(),
                ),
              ),
              Expanded(
                child: LoadFailedView(
                  message: technicianOfferFailureMessage(
                    l10n,
                    state.failure!,
                  ),
                  retryLabel: l10n.retry,
                  onRetry: cubit.load,
                ),
              ),
            ],
          ),
          _ => NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification.metrics.extentAfter < 200) {
                unawaited(cubit.loadMore());
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: cubit.load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  const _Title(),
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 8,
                      children: [
                        ChoiceChipButton(
                          label: l10n.directoryAll,
                          selected: state.categoryId == null,
                          onTap: () => cubit.selectCategory(null),
                        ),
                        for (final category in categories)
                          ChoiceChipButton(
                            label: category.name,
                            icon: categoryIcon(category.id),
                            selected: state.categoryId == category.id,
                            onTap: () => cubit.selectCategory(category.id),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (state.status == OpenRequestsStatus.loading)
                    const Padding(
                      padding: EdgeInsets.only(top: 64),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.requests.isEmpty)
                    const _Empty()
                  else ...[
                    for (final request in state.requests) ...[
                      IncomingRequestCard(
                        request: request,
                        standing: standingOf(request),
                        now: now,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (state.loadingMore)
                      const Padding(
                        padding: EdgeInsets.all(8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ],
              ),
            ),
          ),
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(top: 48),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: colors.inkMuted),
          const SizedBox(height: 12),
          Text(
            l10n.openRequestsEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.openRequestsEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.6, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}
