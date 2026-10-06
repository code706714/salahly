import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/request_draft.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/new_request_cubit.dart';
import 'package:salahly/features/marketplace/presentation/marketplace_labels.dart';
import 'package:salahly/features/marketplace/presentation/pages/new_request_page.dart';
import 'package:salahly/features/marketplace/presentation/pages/request_page.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';

import '../../../../helpers/consumer_app.dart';
import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

void main() {
  late MockNewRequestCubit cubit;
  late MockPhotoPicker picker;

  final now = DateTime(2026, 10, 6, 11, 30);
  final today = DateTime(2026, 10, 6);
  final tomorrow = DateTime(2026, 10, 7);

  final problem = NewRequestState(
    now: now,
    category: TestCategories.airConditioning,
  );
  final address = problem.copyWith(
    step: NewRequestStep.address,
    issue: RequestIssue.notCooling,
    addresses: [testHome, testMomsHome],
    addressId: 'address-1',
  );
  final time = address.copyWith(step: NewRequestStep.time);
  final picked = time.copyWith(
    day: () => tomorrow,
    window: () => RequestWindow.noon,
    photos: ['/p/1.jpg'],
  );

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    ConsumerApp.registerFallbacks();
    registerConsumerScreenFallbacks();
  });

  setUp(() {
    cubit = MockNewRequestCubit();
    when(() => cubit.isClosed).thenReturn(false);
    picker = MockPhotoPicker();
    when(() => cubit.next()).thenAnswer((_) async {});
    when(() => cubit.back()).thenReturn(true);
    when(() => cubit.toggleListening()).thenAnswer((_) async => true);
    when(() => cubit.loadAddresses()).thenAnswer((_) async {});
  });

  Future<ConsumerScreenBlocs> pumpView(
    WidgetTester tester,
    NewRequestState state, {
    ConsumerScreenBlocs? blocs,
    Stream<NewRequestState>? states,
  }) async {
    if (states != null) {
      whenListen(cubit, states, initialState: state);
    } else {
      when(() => cubit.state).thenReturn(state);
    }
    final scope = blocs ?? ConsumerScreenBlocs();
    await tester.pumpApp(
      BlocProvider<NewRequestCubit>.value(
        value: cubit,
        child: const NewRequestView(),
      ),
      repositories: [RepositoryProvider<PhotoPicker>.value(value: picker)],
      blocs: scope.providers,
      stubRoutes: [AppRoutes.request('request-9'), AppRoutes.consumerHome],
    );
    return scope;
  }

  group('step 1: the problem', () {
    testWidgets('shows the issues, the description, dictation and photos on '
        'a small phone', (tester) async {
      await pumpView(tester, problem);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.newRequestTitle('ms', 'تكييف')), findsOneWidget);
      expect(find.text(l10n.newRequestStep(1)), findsOneWidget);
      expect(find.text(l10n.newRequestIssueTitle), findsOneWidget);
      for (final issue in RequestIssue.values) {
        expect(find.text(requestIssueLabel(l10n, issue)), findsOneWidget);
      }
      expect(find.text(l10n.newRequestDictate('ms')), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.newRequestAddPhoto('ms')),
        findsOneWidget,
      );
      expect(find.text(l10n.newRequestNext), findsOneWidget);
    });

    testWidgets('speaks to a man in his words', (tester) async {
      await pumpView(
        tester,
        problem,
        blocs: ConsumerScreenBlocs(
          session: testConsumerSession(honorific: Honorific.mr),
        ),
      );

      expect(find.text(l10n.newRequestTitle('other', 'تكييف')), findsOneWidget);
      expect(find.text(l10n.newRequestDictate('other')), findsOneWidget);
    });

    testWidgets('picks an issue and types the description', (tester) async {
      await pumpView(tester, problem);

      await tester.tap(find.text(l10n.requestIssueLeaking));
      verify(() => cubit.selectIssue(RequestIssue.leaking)).called(1);

      await tester.enterText(find.byType(TextField), 'بينقّط من جوه');
      verify(() => cubit.editDescription('بينقّط من جوه')).called(1);
    });

    testWidgets('fills the field with dictated words', (tester) async {
      final states = StreamController<NewRequestState>();
      await pumpView(tester, problem, states: states.stream);

      states.add(problem.copyWith(description: 'مش بيبرّد', isListening: true));
      await tester.pump();

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'مش بيبرّد',
      );
      expect(find.text(l10n.newRequestListening('ms')), findsOneWidget);
      await states.close();
    });

    testWidgets('dictates, and says when the phone cannot', (tester) async {
      await pumpView(tester, problem);

      await tester.tap(find.text(l10n.newRequestDictate('ms')));
      await tester.pump();
      verify(() => cubit.toggleListening()).called(1);
      expect(find.text(l10n.newRequestSpeechUnavailable('ms')), findsNothing);

      when(() => cubit.toggleListening()).thenAnswer((_) async => false);
      await tester.tap(find.text(l10n.newRequestDictate('ms')));
      await tester.pump();
      expect(find.text(l10n.newRequestSpeechUnavailable('ms')), findsOneWidget);
    });

    testWidgets('says what is missing', (tester) async {
      await pumpView(tester, problem.copyWith(showsErrors: true));
      expect(find.text(l10n.newRequestIssueRequired('ms')), findsOneWidget);
    });

    testWidgets('asks for a description when the issue is something else', (
      tester,
    ) async {
      await pumpView(
        tester,
        problem.copyWith(issue: RequestIssue.other, showsErrors: true),
      );

      expect(find.text(l10n.newRequestIssueRequired('ms')), findsNothing);
      expect(
        find.text(l10n.newRequestDescriptionRequired('ms')),
        findsOneWidget,
      );
    });

    testWidgets('moves on with next', (tester) async {
      await pumpView(tester, problem);

      await tester.tap(find.text(l10n.newRequestNext));
      verify(() => cubit.next()).called(1);
    });

    testWidgets('takes a photo', (tester) async {
      when(
        () => picker.pick(
          source: PhotoSource.camera,
          purpose: PhotoPurpose.request,
        ),
      ).thenAnswer((_) async => '/p/new.jpg');
      await pumpView(tester, problem);

      await tester.ensureVisible(find.byIcon(Icons.photo_camera_outlined));
      await tester.tap(find.byIcon(Icons.photo_camera_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.newRequestPhotoTake('ms')));
      await tester.pumpAndSettle();

      verify(() => cubit.addPhoto('/p/new.jpg')).called(1);
    });

    testWidgets('picks a photo from the gallery, or nothing', (tester) async {
      when(
        () => picker.pick(
          source: PhotoSource.gallery,
          purpose: PhotoPurpose.request,
        ),
      ).thenAnswer((_) async => null);
      await pumpView(tester, problem);

      await tester.ensureVisible(find.byIcon(Icons.photo_camera_outlined));
      await tester.tap(find.byIcon(Icons.photo_camera_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.newRequestPhotoChoose('ms')));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.addPhoto(any()));
    });

    testWidgets('says when the camera is not allowed', (tester) async {
      when(
        () => picker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenThrow(PlatformException(code: 'camera_access_denied'));
      await pumpView(tester, problem);

      await tester.ensureVisible(find.byIcon(Icons.photo_camera_outlined));
      await tester.tap(find.byIcon(Icons.photo_camera_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.newRequestPhotoTake('ms')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.newRequestCameraDenied('ms')), findsOneWidget);
    });

    testWidgets('removes a photo, and takes no more than four', (
      tester,
    ) async {
      await pumpView(
        tester,
        problem.copyWith(
          photos: ['/p/1.jpg', '/p/2.jpg', '/p/3.jpg', '/p/4.jpg'],
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(l10n.newRequestAddPhoto('ms')),
        findsNothing,
      );
      await tester.tap(find.byTooltip(l10n.newRequestRemovePhoto('ms')).at(1));
      verify(() => cubit.removePhoto('/p/2.jpg')).called(1);
    });

    testWidgets('names the technician asked first', (tester) async {
      await pumpView(
        tester,
        problem.copyWith(technician: testTechnicianCard()),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text(l10n.newRequestFirstTechnician('محمود السيد')),
        findsOneWidget,
      );
    });

    testWidgets('waits for the catalog', (tester) async {
      await pumpView(tester, NewRequestState(now: now));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.newRequestTitleAny('ms')), findsOneWidget);
      await tester.tap(find.text(l10n.newRequestNext));
      verifyNever(() => cubit.next());
    });
  });

  group('step 2: the address', () {
    testWidgets('shows the addresses with the picked one, and the privacy '
        'note', (tester) async {
      await pumpView(tester, address);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.newRequestStep(2)), findsOneWidget);
      expect(find.text(l10n.newRequestAddressTitle), findsOneWidget);
      expect(find.text('البيت'), findsOneWidget);
      expect(find.text('بيت ماما'), findsOneWidget);
      expect(find.text('شارع النزهة، مصر الجديدة'), findsOneWidget);
      expect(find.text(l10n.addressesPrivacy('ms')), findsOneWidget);
    });

    testWidgets('picks an address', (tester) async {
      await pumpView(tester, address);

      await tester.tap(find.text('بيت ماما'));
      verify(() => cubit.selectAddress('address-2')).called(1);
    });

    testWidgets('adds a new address and picks it', (tester) async {
      when(() => cubit.addAddress(any())).thenAnswer((_) async => null);
      await pumpView(tester, address);

      await tester.tap(find.text(l10n.addressesNew));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'الشغل');
      await tester.tap(find.text(l10n.addressesAreaPick('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الزمالك').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'شارع 26 يوليو');
      await tester.tap(find.text(l10n.addressesSave('ms')));
      await tester.pumpAndSettle();

      verify(
        () => cubit.addAddress(
          const ConsumerAddressDraft(
            label: 'الشغل',
            areaId: 'zamalek',
            details: 'شارع 26 يوليو',
          ),
        ),
      ).called(1);
      expect(find.text(l10n.addressesSave('ms')), findsNothing);
    });

    testWidgets('says what is missing', (tester) async {
      await pumpView(
        tester,
        address.copyWith(addresses: const [], showsErrors: true),
      );

      expect(find.text(l10n.newRequestAddressRequired('ms')), findsOneWidget);
    });

    testWidgets('retries addresses that could not be fetched', (
      tester,
    ) async {
      await pumpView(
        tester,
        NewRequestState(
          now: now,
          category: TestCategories.airConditioning,
          step: NewRequestStep.address,
          addressesFailed: true,
        ),
      );

      expect(find.text(l10n.addressesLoadFailed), findsOneWidget);
      await tester.tap(find.text(l10n.consumerRetry('ms')));
      verify(() => cubit.loadAddresses()).called(1);
    });

    testWidgets('waits for the addresses', (tester) async {
      await pumpView(
        tester,
        NewRequestState(
          now: now,
          category: TestCategories.airConditioning,
          step: NewRequestStep.address,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('offers no new address once the book is full', (
      tester,
    ) async {
      await pumpView(
        tester,
        address.copyWith(
          addresses: [
            for (var i = 0; i < 10; i++)
              ConsumerAddress(
                id: 'a$i',
                label: 'عنوان $i',
                areaId: 'nasr_city',
                details: 'شارع $i',
              ),
          ],
        ),
      );

      await tester.scrollUntilVisible(
        find.text(l10n.consumerAddressLimit('ms')),
        200,
      );
      expect(find.text(l10n.addressesNew), findsNothing);
    });

    testWidgets('back goes to the first step', (tester) async {
      await pumpView(tester, address);

      await tester.tap(find.byTooltip(l10n.back));
      await tester.pumpAndSettle();

      verify(() => cubit.back()).called(1);
      expect(find.byType(NewRequestView), findsOneWidget);
    });
  });

  group('step 3: the time', () {
    testWidgets('offers the days and the windows still open, and sums the '
        'request up', (tester) async {
      await pumpView(tester, picked.copyWith(technician: testTechnicianCard()));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.newRequestStep(3)), findsOneWidget);
      expect(find.text(l10n.today), findsOneWidget);
      final tomorrowLabel = l10n.newRequestTomorrow(weekdayName(tomorrow));
      expect(find.text(tomorrowLabel), findsOneWidget);
      expect(find.text(weekdayName(DateTime(2026, 10, 8))), findsOneWidget);
      for (final window in RequestWindow.choices) {
        expect(find.text(requestWindowLabel(l10n, window)), findsOneWidget);
      }
      expect(find.text(l10n.newRequestSummary), findsOneWidget);
      expect(
        find.text(
          '${requestTitle(l10n, RequestIssue.notCooling, category: 'تكييف')}'
          ' · ${l10n.newRequestSummaryPhotos(1)}',
        ),
        findsOneWidget,
      );
      expect(find.text('البيت، مدينة نصر'), findsOneWidget);
      expect(
        find.text(
          '$tomorrowLabel، ${requestRangeLabel(l10n, RequestWindow.noon)}',
        ),
        findsOneWidget,
      );
      expect(
        find.text(l10n.newRequestSummaryFirst('محمود السيد')),
        findsOneWidget,
      );
      expect(find.text(l10n.newRequestSend('ms')), findsOneWidget);
    });

    testWidgets('picks a day and a window', (tester) async {
      await pumpView(tester, time);

      await tester.tap(find.text(l10n.today));
      verify(() => cubit.selectDay(today)).called(1);
      await tester.tap(
        find.text(requestWindowLabel(l10n, RequestWindow.evening)),
      );
      verify(() => cubit.selectWindow(RequestWindow.evening)).called(1);
    });

    testWidgets('a window already over today cannot be picked', (
      tester,
    ) async {
      await pumpView(tester, time.copyWith(day: () => today));

      await tester.tap(
        find.text(requestWindowLabel(l10n, RequestWindow.morning)),
      );
      verifyNever(() => cubit.selectWindow(any()));
    });

    testWidgets('today cannot be picked once every window is over', (
      tester,
    ) async {
      await pumpView(tester, time.copyWith(now: DateTime(2026, 10, 6, 20, 30)));

      await tester.tap(find.text(l10n.today));
      verifyNever(() => cubit.selectDay(any()));
    });

    testWidgets('says what is missing', (tester) async {
      await pumpView(tester, time.copyWith(showsErrors: true));

      expect(find.text(l10n.newRequestTimeRequired('ms')), findsOneWidget);
    });

    testWidgets('sends', (tester) async {
      await pumpView(tester, picked);

      await tester.tap(find.text(l10n.newRequestSend('ms')));
      verify(() => cubit.next()).called(1);
    });

    testWidgets('shows how sending goes', (tester) async {
      await pumpView(
        tester,
        picked.copyWith(
          status: NewRequestStatus.uploading,
          photos: ['/p/1.jpg', '/p/2.jpg'],
          uploaded: 1,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.newRequestUploading(2, 2)), findsOneWidget);
      expect(find.text(l10n.newRequestSend('ms')), findsNothing);
    });

    testWidgets('shows sending', (tester) async {
      await pumpView(
        tester,
        picked.copyWith(status: NewRequestStatus.sending),
      );
      expect(find.text(l10n.newRequestSending), findsOneWidget);
    });

    for (final (failure, message) in [
      (const NoCreditsFailure(), null),
      (const NetworkFailure(), null),
      (const InvalidTimeFailure(), l10n.newRequestInvalidTime('ms')),
      (const UploadLimitFailure(), l10n.newRequestUploadLimit('ms')),
      (const UnsupportedPhotoFailure(), l10n.newRequestPhotoRejected('ms')),
    ]) {
      testWidgets('says why sending failed: ${failure.runtimeType}', (
        tester,
      ) async {
        final states = StreamController<NewRequestState>();
        await pumpView(tester, picked, states: states.stream);

        states.add(
          picked.copyWith(
            status: NewRequestStatus.failed,
            failure: () => failure,
          ),
        );
        await tester.pump();

        expect(
          find.text(
            message ?? consumerFailureMessage(l10n, failure, honorific: 'ms'),
          ),
          findsOneWidget,
        );
        await states.close();
      });
    }
  });

  group('sent', () {
    testWidgets('says how many technicians got it', (tester) async {
      await pumpView(
        tester,
        picked.copyWith(
          status: NewRequestStatus.sent,
          sent: const SentRequest(id: 'request-9', sentTo: 5),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.newRequestDone), findsOneWidget);
      expect(find.text(l10n.newRequestSentTitle), findsOneWidget);
      expect(
        find.text(
          '${l10n.newRequestSentTo(5, 'تكييف')} '
          '${l10n.newRequestSentOffers('ms')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says when no technician is free right now', (tester) async {
      await pumpView(
        tester,
        picked.copyWith(
          status: NewRequestStatus.sent,
          sent: const SentRequest(id: 'request-9', sentTo: 0),
        ),
        blocs: ConsumerScreenBlocs(
          session: testConsumerSession(honorific: Honorific.mr),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.text(l10n.newRequestSentToNobody('other', 'تكييف')),
        findsOneWidget,
      );
    });

    testWidgets('reloads the requests once sent', (tester) async {
      final states = StreamController<NewRequestState>();
      final blocs = await pumpView(tester, picked, states: states.stream);

      states.add(
        picked.copyWith(
          status: NewRequestStatus.sent,
          sent: const SentRequest(id: 'request-9', sentTo: 5),
        ),
      );
      await tester.pump();

      verify(blocs.myRequests.load).called(1);
      await states.close();
    });

    testWidgets('follows the request in place of the form', (tester) async {
      await pumpView(
        tester,
        picked.copyWith(
          status: NewRequestStatus.sent,
          sent: const SentRequest(id: 'request-9', sentTo: 5),
        ),
      );

      await tester.tap(find.text(l10n.consumerHomeFollow('ms')));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.request('request-9')), findsOneWidget);
      expect(find.byType(NewRequestView), findsNothing);
    });

    testWidgets('goes back home', (tester) async {
      await pumpView(
        tester,
        picked.copyWith(
          status: NewRequestStatus.sent,
          sent: const SentRequest(id: 'request-9', sentTo: 5),
        ),
      );

      await tester.tap(find.text(l10n.newRequestBackHome));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.consumerHome), findsOneWidget);
    });
  });

  group('NewRequestPage', () {
    testConsumerApp('asks for a technician from start to end', (
      tester,
      app,
    ) async {
      when(
        app.requests.fetchAddresses,
      ).thenAnswer((_) async => const Ok([testHome, testMomsHome]));
      when(
        () => app.photoPicker.pick(
          source: PhotoSource.gallery,
          purpose: PhotoPurpose.request,
        ),
      ).thenAnswer((_) async => '/phone/ac.jpg');
      when(
        () => app.requests.uploadPhoto('/phone/ac.jpg'),
      ).thenAnswer((_) async => const Ok('consumer-1/ac.jpg'));
      when(() => app.requests.sendRequest(any())).thenAnswer(
        (_) async => const Ok(SentRequest(id: 'request-9', sentTo: 5)),
      );
      when(
        () => app.requests.fetchRequest('request-9'),
      ).thenAnswer((_) async => Ok(testRequestDetails(id: 'request-9')));
      await app.pump(tester);
      await tester.tap(find.text(l10n.newRequestTitle('ms', 'تكييف')));
      await app.settle(tester);

      await tester.tap(find.text(l10n.newRequestNext));
      await app.settle(tester);
      expect(find.text(l10n.newRequestIssueRequired('ms')), findsOneWidget);

      await tester.tap(find.text(l10n.requestIssueNotCooling));
      await app.settle(tester);
      await tester.enterText(find.byType(TextField), 'الهوا مش ساقع');
      await tester.ensureVisible(find.byIcon(Icons.photo_camera_outlined));
      await tester.tap(find.byIcon(Icons.photo_camera_outlined));
      await app.settle(tester);
      await tester.tap(find.text(l10n.newRequestPhotoChoose('ms')));
      await app.settle(tester);
      expect(find.byTooltip(l10n.newRequestRemovePhoto('ms')), findsOneWidget);
      await tester.tap(find.text(l10n.newRequestNext));
      await app.settle(tester);

      expect(find.text(l10n.newRequestAddressTitle), findsOneWidget);
      await tester.tap(find.text('بيت ماما'));
      await tester.tap(find.text(l10n.newRequestNext));
      await app.settle(tester);

      expect(find.text(l10n.newRequestTimeTitle), findsOneWidget);
      final day = tester
          .element(find.text(l10n.newRequestTimeTitle))
          .read<NewRequestCubit>()
          .state
          .days[1];
      await tester.tap(find.textContaining(weekdayName(day)).first);
      await tester.tap(find.text(requestWindowLabel(l10n, RequestWindow.noon)));
      await app.settle(tester);
      await tester.tap(find.text(l10n.newRequestSend('ms')));
      await app.settle(tester);

      verify(
        () => app.requests.sendRequest(
          RequestDraft(
            categoryId: 'ac',
            issue: RequestIssue.notCooling,
            description: 'الهوا مش ساقع',
            photoPaths: const ['consumer-1/ac.jpg'],
            addressId: 'address-2',
            day: day,
            window: RequestWindow.noon,
          ),
        ),
      ).called(1);
      expect(find.text(l10n.newRequestSentTitle), findsOneWidget);
      verify(app.requests.fetchRequests).called(greaterThan(1));

      await tester.tap(find.text(l10n.consumerHomeFollow('ms')));
      await app.settle(tester);
      expect(find.byType(RequestPage), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.back).first);
      await app.settle(tester);
      expect(find.byType(NewRequestPage), findsNothing);
      expect(find.text(l10n.newRequestTitle('ms', 'تكييف')), findsOneWidget);
    });

    testConsumerApp('goes back a step, then leaves the form', (
      tester,
      app,
    ) async {
      await app.pump(tester);
      unawaited(
        app.router(tester).push(AppRoutes.newRequestFor(categoryId: 'ac')),
      );
      await app.settle(tester);
      await tester.tap(find.text(l10n.requestIssueNoisy));
      await tester.tap(find.text(l10n.newRequestNext));
      await app.settle(tester);
      expect(find.text(l10n.newRequestAddressTitle), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.back));
      await app.settle(tester);
      expect(find.text(l10n.newRequestIssueTitle), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.back));
      await app.settle(tester);
      expect(find.byType(NewRequestPage), findsNothing);
    });

    testConsumerApp('says when she has no requests left', (tester, app) async {
      when(
        app.requests.fetchAddresses,
      ).thenAnswer((_) async => const Ok([testHome]));
      when(
        () => app.requests.sendRequest(any()),
      ).thenAnswer((_) async => const Err(NoCreditsFailure()));
      await app.pump(tester);
      unawaited(
        app.router(tester).push(AppRoutes.newRequestFor(categoryId: 'ac')),
      );
      await app.settle(tester);
      await tester.tap(find.text(l10n.requestIssueNoisy));
      await tester.tap(find.text(l10n.newRequestNext));
      await app.settle(tester);
      await tester.tap(find.text(l10n.newRequestNext));
      await app.settle(tester);
      final day = tester
          .element(find.text(l10n.newRequestTimeTitle))
          .read<NewRequestCubit>()
          .state
          .days[1];
      await tester.tap(find.textContaining(weekdayName(day)).first);
      await tester.tap(
        find.text(requestWindowLabel(l10n, RequestWindow.evening)),
      );
      await tester.tap(find.text(l10n.newRequestSend('ms')));
      await app.settle(tester);

      expect(
        find.text(
          consumerFailureMessage(
            l10n,
            const NoCreditsFailure(),
            honorific: 'ms',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.newRequestSend('ms')), findsOneWidget);
    });
  });
}
