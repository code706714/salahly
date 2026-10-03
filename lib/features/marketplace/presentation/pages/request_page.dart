import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/account/presentation/cubit/consumer_session.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/closed_request_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/done_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/offers_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/price_change_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/request_unavailable_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/track_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/waiting_view.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One of the consumer's requests. Shows the screen for where it stands,
/// and moves on by itself as offers and the technician's progress arrive.
class RequestPage extends StatelessWidget {
  const RequestPage({required this.requestId, super.key});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final cubit = RequestCubit(
          requests: context.read(),
          requestId: requestId,
        );
        unawaited(cubit.start());
        return cubit;
      },
      child: const _RequestScreen(),
    );
  }
}

class _RequestScreen extends StatelessWidget {
  const _RequestScreen();

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // The list behind this screen shows where the request stands too.
        BlocListener<RequestCubit, RequestState>(
          listenWhen: (previous, current) =>
              previous.details != null && previous.details != current.details,
          listener: (context, state) =>
              unawaited(context.read<MyRequestsCubit>().load()),
        ),
        BlocListener<RequestCubit, RequestState>(
          listenWhen: (previous, current) =>
              previous.failure != current.failure && current.failure != null,
          listener: (context, state) => ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  consumerFailureMessage(
                    AppLocalizations.of(context),
                    state.failure!,
                    honorific: context.readHonorific(),
                  ),
                ),
              ),
            ),
        ),
      ],
      child: BlocBuilder<RequestCubit, RequestState>(
        builder: (context, state) {
          final details = state.details;
          if (details == null) {
            return switch (state.status) {
              RequestLoadStatus.loading => const Scaffold(),
              RequestLoadStatus.missing ||
              RequestLoadStatus.ready => const RequestUnavailableView(
                missing: true,
              ),
              RequestLoadStatus.failed => const RequestUnavailableView(
                missing: false,
              ),
            };
          }
          if (details.hasPendingPriceChange) {
            return PriceChangeView(details: details);
          }
          return switch (details.stage) {
            RequestStage.waitingForOffers => WaitingView(details: details),
            RequestStage.choosingOffer => OffersView(details: details),
            RequestStage.chosen ||
            RequestStage.confirmed ||
            RequestStage.started => TrackView(details: details),
            RequestStage.done => DoneView(details: details),
            RequestStage.cancelled ||
            RequestStage.expired => ClosedRequestView(details: details),
          };
        },
      ),
    );
  }
}
