import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';
import 'package:salahly/features/marketplace/presentation/widgets/incoming/incoming_request_card.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// New requests near the technician, to open and answer.
///
/// The list is shared with "النهارده" and fetched again on opening.
class IncomingRequestsPage extends StatefulWidget {
  const IncomingRequestsPage({super.key});

  @override
  State<IncomingRequestsPage> createState() => _IncomingRequestsPageState();
}

class _IncomingRequestsPageState extends State<IncomingRequestsPage> {
  @override
  void initState() {
    super.initState();
    unawaited(context.read<IncomingRequestsCubit>().fetchNewRequests());
  }

  @override
  Widget build(BuildContext context) => const IncomingRequestsView();
}

class IncomingRequestsView extends StatelessWidget {
  const IncomingRequestsView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cubit = context.read<IncomingRequestsCubit>();
    final state = context.watch<IncomingRequestsCubit>().state;
    final now = DateTime.now();
    final requests = state.requests;

    return Scaffold(
      appBar: DetailHeader(title: l10n.incomingTitle),
      body: switch (state.status) {
        IncomingRequestsStatus.loading when requests.isEmpty => const Center(
          child: CircularProgressIndicator(),
        ),
        IncomingRequestsStatus.failed when requests.isEmpty => _LoadFailed(
          onRetry: cubit.fetchNewRequests,
        ),
        _ => RefreshIndicator(
          onRefresh: cubit.fetchNewRequests,
          child: ListView.separated(
            // Pull to refresh works on a short list too.
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            itemCount: requests.isEmpty ? 1 : requests.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (requests.isEmpty) return const _Empty();
              final request = requests[index];
              return IncomingRequestCard(
                request: request,
                standing: standingOf(
                  request,
                  closedSince: state.closedIds.contains(request.id),
                ),
                now: now,
              );
            },
          ),
        ),
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            l10n.incomingEmpty,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.incomingEmptyHint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colors.inkMuted),
          ),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.incomingLoadFailed,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: context.appColors.inkMuted,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}
