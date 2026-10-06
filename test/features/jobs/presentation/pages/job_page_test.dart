import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/presentation/cubit/job_details_cubit.dart';
import 'package:salahly/features/jobs/presentation/pages/job_page.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/job_details_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pushed_view.dart';
import '../../../../pump_app.dart';

class _MockJobDetailsCubit extends MockCubit<JobDetailsState>
    implements JobDetailsCubit {}

void main() {
  late _MockJobDetailsCubit cubit;
  late MockSyncCubit sync;
  late MockAreasCubit areas;
  late MockExternalApps apps;
  late MockPhotoPicker picker;
  final today = DateTime(2026, 10, 2, 11);
  final phone = PhoneNumber.tryParse('01002345678')!;

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    registerFallbackValue(phone);
    registerFallbackValue(PhotoSource.camera);
    registerFallbackValue(PhotoPurpose.job);
    registerFallbackValue(PhotoKind.before);
    registerFallbackValue(
      JobChange(previous: testJob(), to: JobStatus.started),
    );
  });

  setUp(() {
    cubit = _MockJobDetailsCubit();
    sync = MockSyncCubit();
    areas = MockAreasCubit();
    apps = MockExternalApps();
    picker = MockPhotoPicker();
    when(() => sync.state).thenReturn(const SyncState());
    when(
      () => areas.state,
    ).thenReturn(const AreasState(areas: TestAreas.all));
    when(() => cubit.advance()).thenAnswer((_) async {});
    when(() => cubit.cancel()).thenAnswer((_) async {});
    when(() => cubit.reschedule(any())).thenAnswer((_) async {});
    when(() => cubit.delete()).thenAnswer((_) async {});
    when(() => cubit.undo(any())).thenAnswer((_) async {});
    when(() => cubit.addPhoto(any(), any())).thenAnswer((_) async {});
    when(() => cubit.deletePhoto(any())).thenAnswer((_) async {});
  });

  JobDetailsState ready(JobDetails details) => JobDetailsState(
    today: today,
    status: JobDetailsStatus.ready,
    details: details,
  );

  JobDetails visit({
    JobStatus status = JobStatus.confirmed,
    QuoteStatus quoteStatus = QuoteStatus.sent,
    List<JobPhoto> photos = const [],
    bool isSynced = true,
    bool priced = true,
    JobSource source = JobSource.manual,
  }) => testDetails(
    job: testJob(
      source: source,
      status: status,
      tags: [JobTag.installation],
      description: 'العميل جايب الوحدة.',
      scheduledAt: DateTime(2026, 10, 2, 13),
      quoteStatus: quoteStatus,
    ),
    items: priced ? sampleItems : const [],
    payments: status == JobStatus.paid ? [testPayment(1450)] : const [],
    photos: photos,
    isSynced: isSynced,
  );

  void show(JobDetailsState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpPage(
    WidgetTester tester, {
    Widget view = const JobView(),
  }) => tester.pumpApp(
    view,
    repositories: [
      RepositoryProvider<ExternalApps>.value(value: apps),
      RepositoryProvider<PhotoPicker>.value(value: picker),
    ],
    blocs: [
      BlocProvider<JobDetailsCubit>.value(value: cubit),
      BlocProvider<SyncCubit>.value(value: sync),
      BlocProvider<AreasCubit>.value(value: areas),
    ],
    stubRoutes: [
      AppRoutes.jobQuote('job-1'),
      AppRoutes.jobInvoice('job-1'),
      AppRoutes.customer('customer-1'),
    ],
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('states', () {
    testWidgets('shows nothing while loading', (tester) async {
      show(JobDetailsState(today: today));
      await pumpPage(tester);
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.text(l10n.jobPageCustomer), findsNothing);
    });

    testWidgets('says when the job is not on this phone', (tester) async {
      show(JobDetailsState(today: today, status: JobDetailsStatus.missing));
      await pumpPage(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobUntitled), findsOneWidget);
      expect(find.text(l10n.jobPageMissing), findsOneWidget);
    });

    testWidgets('shows a confirmed visit from top to bottom', (tester) async {
      show(ready(visit()));
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobTagInstallation), findsWidgets);
      expect(
        find.text('${l10n.today} 1:00 ${l10n.periodNoon}'),
        findsOneWidget,
      );
      // The confirmed pill and the first step share a word.
      expect(find.text(l10n.jobStatusConfirmed), findsNWidgets(2));
      expect(find.text(l10n.jobPageStepPaid), findsOneWidget);
      expect(find.text('م. شريف عادل'), findsOneWidget);
      expect(find.text('0100 234 5678'), findsOneWidget);
      expect(find.text('12 شارع الأهرام، مصر الجديدة'), findsOneWidget);
      expect(find.text('العميل جايب الوحدة.'), findsOneWidget);
      expect(find.text(l10n.jobPageStart), findsOneWidget);

      await scrollTo(tester, find.text(l10n.jobPageInvoice));
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobQuoteSent), findsOneWidget);
      expect(find.text(l10n.jobPageItemCount(3)), findsOneWidget);
      expect(find.text(l10n.pounds('1,450')), findsNWidgets(2));
      expect(find.text(l10n.pounds('0')), findsOneWidget);
    });

    testWidgets('names a visit without a day', (tester) async {
      show(ready(testDetails()));
      await pumpPage(tester);
      expect(find.text(l10n.jobPageNoDate), findsOneWidget);
    });

    testWidgets('leaves out what the customer has not given', (tester) async {
      show(
        ready(
          testDetails(
            job: testJob(tags: const []),
            customer: testCustomer(phone: null, areaId: null, address: null),
          ),
        ),
      );
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.byTooltip(l10n.jobPageCall), findsNothing);
      expect(find.byTooltip(l10n.jobPageWhatsapp), findsNothing);
      expect(find.text(l10n.jobPageMap), findsNothing);
      expect(find.text(l10n.jobPageProblem), findsNothing);
    });

    testWidgets('marks a job not sent yet while offline', (tester) async {
      when(() => sync.state).thenReturn(const SyncState(hasNetwork: false));
      show(ready(visit(isSynced: false)));
      await pumpPage(tester);
      expect(find.text(l10n.jobPendingSync), findsOneWidget);

      show(ready(visit()));
      await pumpPage(tester);
      expect(find.text(l10n.jobPendingSync), findsNothing);
    });

    testWidgets('names each status and its next step', (tester) async {
      for (final (status, pill, button) in [
        (JobStatus.unconfirmed, l10n.jobStatusUnconfirmed, l10n.jobPageConfirm),
        (JobStatus.started, l10n.jobPageStatusStarted, l10n.jobPageFinish),
        (
          JobStatus.finished,
          l10n.jobPageStatusAwaitingPayment,
          l10n.jobPageCollect,
        ),
      ]) {
        show(ready(visit(status: status)));
        await pumpPage(tester);
        expect(tester.takeException(), isNull);
        expect(find.text(pill), findsOneWidget, reason: '$status');
        expect(find.text(button), findsOneWidget, reason: '$status');
      }
    });

    testWidgets('a finished job without a price is just finished', (
      tester,
    ) async {
      show(ready(visit(status: JobStatus.finished, priced: false)));
      await pumpPage(tester);
      expect(find.text(l10n.jobStatusFinished), findsOneWidget);
      await scrollTo(tester, find.text(l10n.jobPageQuoteCreate));
      expect(find.text(l10n.jobPageItemCount(0)), findsOneWidget);
    });

    testWidgets('a paid job has no next step', (tester) async {
      show(
        ready(visit(status: JobStatus.paid, quoteStatus: QuoteStatus.accepted)),
      );
      await pumpPage(tester);
      expect(find.text(l10n.jobStatusPaid), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      await scrollTo(tester, find.text(l10n.jobPageInvoice));
      expect(find.text(l10n.jobPageQuoteAccepted), findsOneWidget);
    });

    testWidgets('a cancelled job has no steps', (tester) async {
      show(ready(visit(status: JobStatus.cancelled)));
      await pumpPage(tester);
      expect(find.text(l10n.jobStatusCancelled), findsOneWidget);
      expect(find.text(l10n.jobPageStepPaid), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('marks a quote not sent yet', (tester) async {
      show(ready(visit(quoteStatus: QuoteStatus.draft)));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.jobPageInvoice));
      expect(find.text(l10n.jobPageQuoteDraft), findsOneWidget);
    });

    testWidgets('says why an action failed', (tester) async {
      show(ready(visit()));
      whenListen(
        cubit,
        Stream.value(
          ready(visit()).copyWith(failure: () => const UnexpectedFailure('x')),
        ),
        initialState: ready(visit()),
      );
      await pumpPage(tester);
      await tester.pump();
      expect(find.text(l10n.errorUnexpected), findsOneWidget);
    });
  });

  testWidgets('leaves once the job is deleted', (tester) async {
    final states = StreamController<JobDetailsState>();
    addTearDown(states.close);
    whenListen(cubit, states.stream, initialState: ready(visit()));
    await pumpPage(tester, view: const PushedView(JobView()));
    await tester.openPushedView();
    expect(find.text(l10n.jobPageStart), findsOneWidget);

    states.add(ready(visit()).copyWith(status: JobDetailsStatus.deleted));
    await tester.pumpAndSettle();

    expect(find.text(PushedView.launcher), findsOneWidget);
    expect(find.text(l10n.jobPageStart), findsNothing);
  });

  group('next step', () {
    testWidgets('moves the job on and offers to undo it', (tester) async {
      final change = JobChange(
        previous: visit().job,
        to: JobStatus.started,
      );
      final states = StreamController<JobDetailsState>();
      addTearDown(states.close);
      whenListen(cubit, states.stream, initialState: ready(visit()));
      when(() => cubit.advance()).thenAnswer(
        (_) async => states.add(
          ready(visit(status: JobStatus.started)).copyWith(
            change: () => change,
          ),
        ),
      );
      await pumpPage(tester);

      await tester.tap(find.text(l10n.jobPageStart));
      await tester.pumpAndSettle();

      verify(() => cubit.advance()).called(1);
      expect(find.text(l10n.jobPageStarted), findsOneWidget);
      await tester.tap(find.text(l10n.jobPageUndo));
      verify(() => cubit.undo(change)).called(1);
    });

    testWidgets('names each change in its undo note', (tester) async {
      for (final (to, message) in [
        (JobStatus.confirmed, l10n.jobPageConfirmed),
        (JobStatus.finished, l10n.jobPageFinished),
        (JobStatus.paid, l10n.jobPageFinished),
        (JobStatus.cancelled, l10n.jobPageCancelled),
      ]) {
        whenListen(
          cubit,
          Stream.value(
            ready(visit(status: to)).copyWith(
              change: () => JobChange(previous: visit().job, to: to),
            ),
          ),
          initialState: ready(visit()),
        );
        await pumpPage(tester);
        await tester.pump();
        expect(find.text(message), findsOneWidget, reason: '$to');
      }
    });

    testWidgets('a finished job goes to collecting the money', (
      tester,
    ) async {
      show(ready(visit(status: JobStatus.finished)));
      await pumpPage(tester);

      await tester.tap(find.text(l10n.jobPageCollect));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.jobInvoice('job-1')), findsOneWidget);
      verifyNever(() => cubit.advance());
    });
  });

  group('more', () {
    testWidgets('cancels an open job', (tester) async {
      show(ready(visit()));
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.jobPageMore));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.jobPageCancel));
      await tester.pumpAndSettle();

      verify(() => cubit.cancel()).called(1);
    });

    testWidgets('moves the visit or takes its date off', (tester) async {
      show(ready(visit()));
      await pumpPage(tester);

      Future<void> openReschedule() async {
        await tester.tap(find.byTooltip(l10n.jobPageMore));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.jobPageReschedule));
        await tester.pumpAndSettle();
        expect(find.text(l10n.newJobScheduleTitle), findsOneWidget);
      }

      await openReschedule();
      await tester.tap(find.text(l10n.newJobScheduleDone));
      await tester.pumpAndSettle();
      verify(() => cubit.reschedule(DateTime(2026, 10, 2, 13))).called(1);

      await openReschedule();
      await tester.tap(find.text(l10n.newJobNoDate));
      await tester.pumpAndSettle();
      verify(() => cubit.reschedule(null)).called(1);
    });

    testWidgets('a started job keeps its date', (tester) async {
      show(ready(visit(status: JobStatus.started)));
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.jobPageMore));
      await tester.pumpAndSettle();

      expect(find.text(l10n.jobPageReschedule), findsNothing);
      expect(find.text(l10n.jobPageCancel), findsOneWidget);
    });

    testWidgets('a finished job cannot be cancelled', (tester) async {
      show(ready(visit(status: JobStatus.finished)));
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.jobPageMore));
      await tester.pumpAndSettle();

      expect(find.text(l10n.jobPageCancel), findsNothing);
      expect(find.text(l10n.jobPageDelete), findsOneWidget);
    });

    testWidgets('deletes the job once confirmed', (tester) async {
      show(ready(visit()));
      await pumpPage(tester);

      Future<void> openDelete() async {
        await tester.tap(find.byTooltip(l10n.jobPageMore));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.jobPageDelete));
        await tester.pumpAndSettle();
        expect(find.text(l10n.jobPageDeleteTitle), findsOneWidget);
      }

      await openDelete();
      await tester.tap(find.text(l10n.jobPageKeep));
      await tester.pumpAndSettle();
      verifyNever(() => cubit.delete());

      await openDelete();
      await tester.tap(find.text(l10n.jobPageDeleteConfirm));
      await tester.pumpAndSettle();
      verify(() => cubit.delete()).called(1);
    });
  });

  group('platform job', () {
    JobDetails platform({
      JobStatus status = JobStatus.confirmed,
      QuoteStatus quoteStatus = QuoteStatus.accepted,
    }) => visit(
      status: status,
      quoteStatus: quoteStatus,
      source: JobSource.platform,
    );

    testWidgets('says it came from the platform', (tester) async {
      await tester.binding.setSurfaceSize(smallPhone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      show(ready(platform()));
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobFromPlatform), findsOneWidget);
      await scrollTo(tester, find.text(l10n.jobPageInvoice));
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobPageQuoteAccepted), findsOneWidget);
    });

    testWidgets('shows a declined price change', (tester) async {
      show(ready(platform(quoteStatus: QuoteStatus.declined)));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.jobPageInvoice));

      expect(find.text(l10n.platformJobQuoteDeclined), findsOneWidget);
    });

    testWidgets('is never deleted, and cancelled only once confirmed', (
      tester,
    ) async {
      show(ready(platform()));
      await pumpPage(tester);

      Future<void> openCancel() async {
        await tester.tap(find.byTooltip(l10n.jobPageMore));
        await tester.pumpAndSettle();
        expect(find.text(l10n.jobPageDelete), findsNothing);
        await tester.tap(find.text(l10n.jobPageCancel));
        await tester.pumpAndSettle();
        expect(find.text(l10n.platformJobCancelBody), findsOneWidget);
      }

      await openCancel();
      await tester.tap(find.text(l10n.jobPageKeep));
      await tester.pumpAndSettle();
      verifyNever(() => cubit.cancel());

      await openCancel();
      await tester.tap(find.text(l10n.platformJobCancelConfirm));
      await tester.pumpAndSettle();
      verify(() => cubit.cancel()).called(1);
    });

    testWidgets('offers nothing more once over', (tester) async {
      for (final status in [JobStatus.finished, JobStatus.cancelled]) {
        show(ready(platform(status: status)));
        await pumpPage(tester);
        expect(find.byTooltip(l10n.jobPageMore), findsNothing);
      }
    });

    testWidgets('a cancelled platform job is not offered back', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.value(
          ready(platform(status: JobStatus.cancelled)).copyWith(
            change: () => JobChange(
              previous: platform().job,
              to: JobStatus.cancelled,
            ),
          ),
        ),
        initialState: ready(platform()),
      );
      await pumpPage(tester);
      await tester.pump();

      expect(find.text(l10n.jobPageCancelled), findsOneWidget);
      expect(find.text(l10n.jobPageUndo), findsNothing);
    });
  });

  group('customer', () {
    testWidgets('calls the customer', (tester) async {
      when(() => apps.dial(any())).thenAnswer((_) async => true);
      show(ready(visit()));
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.jobPageCall));
      await tester.pump();

      verify(() => apps.dial(phone)).called(1);
    });

    testWidgets('says when the call could not start', (tester) async {
      when(() => apps.dial(any())).thenAnswer((_) async => false);
      show(ready(visit()));
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.jobPageCall));
      await tester.pump();

      expect(find.text(l10n.dialFailed), findsOneWidget);
    });

    testWidgets('greets the customer on WhatsApp', (tester) async {
      when(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => true);
      show(ready(visit()));
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.jobPageWhatsapp));
      await tester.pump();

      verify(
        () => apps.whatsApp(text: 'أهلاً م. شريف عادل', to: phone),
      ).called(1);
    });

    testWidgets('opens the address on the map', (tester) async {
      when(() => apps.map(any())).thenAnswer((_) async => true);
      show(ready(visit()));
      await pumpPage(tester);

      await tester.tap(find.text(l10n.jobPageMap));
      await tester.pump();

      verify(() => apps.map('12 شارع الأهرام، مصر الجديدة')).called(1);
    });

    testWidgets('opens the customer', (tester) async {
      show(ready(visit()));
      await pumpPage(tester);

      await tester.tap(find.text('م. شريف عادل'));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.customer('customer-1')), findsOneWidget);
    });
  });

  group('photos', () {
    setUp(
      () => when(
        () => picker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenAnswer((_) async => '/photos/picked.jpg'),
    );

    Future<void> pickFrom(
      WidgetTester tester,
      Finder tile,
      String source,
    ) async {
      await scrollTo(tester, tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.text(source));
      await tester.pumpAndSettle();
    }

    testWidgets('takes a photo before the work', (tester) async {
      show(ready(visit()));
      await pumpPage(tester);

      await pickFrom(
        tester,
        find.bySemanticsLabel(l10n.jobPageAddBefore),
        l10n.photoTake,
      );

      verify(
        () =>
            picker.pick(source: PhotoSource.camera, purpose: PhotoPurpose.job),
      ).called(1);
      verify(
        () => cubit.addPhoto(PhotoKind.before, '/photos/picked.jpg'),
      ).called(1);
    });

    testWidgets('adds a photo after the work from the gallery', (
      tester,
    ) async {
      show(ready(visit(status: JobStatus.started)));
      await pumpPage(tester);

      await pickFrom(
        tester,
        find.text(l10n.jobPageTakeAfter),
        l10n.photoChoose,
      );

      verify(
        () => cubit.addPhoto(PhotoKind.after, '/photos/picked.jpg'),
      ).called(1);
    });

    testWidgets('keeps nothing when no photo was picked', (tester) async {
      when(
        () => picker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenAnswer((_) async => null);
      show(ready(visit()));
      await pumpPage(tester);

      await pickFrom(
        tester,
        find.bySemanticsLabel(l10n.jobPageAddBefore),
        l10n.photoTake,
      );

      verifyNever(() => cubit.addPhoto(any(), any()));
    });

    testWidgets('says when the camera is not allowed', (tester) async {
      when(
        () => picker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenThrow(PlatformException(code: 'camera_access_denied'));
      show(ready(visit()));
      await pumpPage(tester);

      await pickFrom(
        tester,
        find.bySemanticsLabel(l10n.jobPageAddBefore),
        l10n.photoTake,
      );

      expect(find.text(l10n.photoCameraDenied), findsOneWidget);
      verifyNever(() => cubit.addPhoto(any(), any()));
    });

    testWidgets('shows the photos and adds more after the work', (
      tester,
    ) async {
      show(
        ready(
          visit(
            photos: [
              testPhoto(),
              testPhoto(id: 'photo-2', kind: PhotoKind.after),
            ],
          ),
        ),
      );
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.jobPageQuote));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.jobPagePhoto), findsNWidgets(2));
      expect(find.text(l10n.jobPageTakeAfter), findsNothing);
      expect(find.bySemanticsLabel(l10n.jobPageAddAfter), findsOneWidget);
    });

    testWidgets('opens a photo and deletes it once confirmed', (
      tester,
    ) async {
      show(ready(visit(photos: [testPhoto()])));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.jobPagePhoto));

      await tester.tap(find.text(l10n.jobPagePhoto));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip(l10n.jobPagePhotoDelete));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.jobPageKeep));
      await tester.pumpAndSettle();
      verifyNever(() => cubit.deletePhoto(any()));

      await tester.tap(find.byTooltip(l10n.jobPagePhotoDelete));
      await tester.pumpAndSettle();
      expect(find.text(l10n.jobPagePhotoDeleteTitle), findsOneWidget);
      await tester.tap(find.text(l10n.jobPageDeleteConfirm));
      await tester.pumpAndSettle();

      verify(() => cubit.deletePhoto('photo-1')).called(1);
      expect(find.byTooltip(l10n.jobPagePhotoDelete), findsNothing);
    });

    testWidgets('closes a photo', (tester) async {
      show(ready(visit(photos: [testPhoto()])));
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.jobPagePhoto));

      await tester.tap(find.text(l10n.jobPagePhoto));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(l10n.jobPagePhotoClose));
      await tester.pumpAndSettle();

      expect(find.byTooltip(l10n.jobPagePhotoDelete), findsNothing);
      verifyNever(() => cubit.deletePhoto(any()));
    });
  });

  group('money', () {
    testWidgets('opens the quote', (tester) async {
      show(ready(visit()));
      await pumpPage(tester);

      await scrollTo(tester, find.text(l10n.jobPageItemCount(3)));
      await tester.tap(find.text(l10n.jobPageItemCount(3)));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.jobQuote('job-1')), findsOneWidget);
    });

    testWidgets('opens the invoice', (tester) async {
      show(ready(visit()));
      await pumpPage(tester);

      await scrollTo(tester, find.text(l10n.jobPageInvoice));
      await tester.tap(find.text(l10n.jobPageInvoice));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.jobInvoice('job-1')), findsOneWidget);
    });
  });
}
