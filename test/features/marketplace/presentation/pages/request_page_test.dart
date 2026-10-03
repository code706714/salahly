import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/closed_request_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/done_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/offers_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/price_change_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/request_unavailable_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/track_view.dart';
import 'package:salahly/features/marketplace/presentation/widgets/request/waiting_view.dart';

import '../../../../helpers/consumer_app.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
  });

  void serve(ConsumerApp app, Result<RequestDetails?> result) => when(
    () => app.requests.fetchRequest('request-1'),
  ).thenAnswer((_) async => result);

  Future<void> open(WidgetTester tester, ConsumerApp app) =>
      app.pump(tester, location: AppRoutes.request('request-1'));

  group('shows the screen for where the request stands', () {
    for (final (name, details, view) in [
      ('no offers yet', testRequestDetails(), WaitingView),
      ('offers', testRequestDetails(offers: testOffers()), OffersView),
      (
        'picked',
        testRequestDetails(job: testRequestJob(status: JobStatus.unconfirmed)),
        TrackView,
      ),
      ('confirmed', testRequestDetails(job: testRequestJob()), TrackView),
      (
        'working',
        testRequestDetails(job: testRequestJob(status: JobStatus.started)),
        TrackView,
      ),
      (
        'a new price',
        testRequestDetails(job: testPriceChangeJob()),
        PriceChangeView,
      ),
      (
        'finished',
        testRequestDetails(job: testRequestJob(status: JobStatus.finished)),
        DoneView,
      ),
      (
        'cancelled',
        testRequestDetails(
          status: RequestStatus.cancelled,
          cancelledBy: UserRole.consumer,
        ),
        ClosedRequestView,
      ),
      (
        'expired',
        testRequestDetails(status: RequestStatus.expired),
        ClosedRequestView,
      ),
    ]) {
      testConsumerApp(name, (tester, app) async {
        serve(app, Ok(details));

        await open(tester, app);

        expect(find.byType(view), findsOneWidget);
      });
    }
  });

  testConsumerApp('says when the request is gone', (tester, app) async {
    serve(app, const Ok(null));

    await open(tester, app);

    expect(find.text(l10n.marketplaceNotFound), findsOneWidget);
    expect(find.text(l10n.consumerRetry('ms')), findsNothing);
  });

  testConsumerApp('retries a request that could not be fetched', (
    tester,
    app,
  ) async {
    serve(app, const Err(NetworkFailure()));
    await open(tester, app);
    expect(find.byType(RequestUnavailableView), findsOneWidget);
    expect(find.text(l10n.requestLoadFailed), findsOneWidget);

    serve(app, Ok(testRequestDetails()));
    await tester.tap(find.text(l10n.consumerRetry('ms')));
    await app.settle(tester);

    expect(find.byType(WaitingView), findsOneWidget);
  });

  testConsumerApp('moves on when the request changes, and refreshes the '
      'list behind it', (tester, app) async {
    serve(app, Ok(testRequestDetails()));
    await open(tester, app);
    clearInteractions(app.requests);

    serve(app, Ok(testRequestDetails(offers: testOffers())));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(seconds: 20));
    await app.settle(tester);

    expect(find.byType(OffersView), findsOneWidget);
    verify(app.requests.fetchRequests).called(1);
  });

  testConsumerApp('tells why an action failed, in her words', (
    tester,
    app,
  ) async {
    serve(app, Ok(testRequestDetails(offers: testOffers())));
    when(
      () => app.requests.acceptOffer(any()),
    ).thenAnswer((_) async => const Err(OfferExpiredFailure()));
    await open(tester, app);

    final cubit = tester.element(find.byType(OffersView)).read<RequestCubit>();
    await tester.runAsync(() => cubit.acceptOffer('offer-1'));
    await app.settle(tester);

    expect(find.text(l10n.consumerOfferExpired('ms')), findsOneWidget);
  });
}
