import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/complaint_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/complaint_page.dart';

import '../../../../helpers/follow_up_harness.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  late FollowUpHarness harness;

  setUpAll(() async {
    await loadAppFonts();
    FollowUpHarness.registerFallbacks();
    registerFallbackValue(PhotoSource.camera);
    registerFallbackValue(PhotoPurpose.job);
  });

  setUp(() {
    harness = FollowUpHarness();
    when(
      () => harness.complaint.send(details: any(named: 'details')),
    ).thenAnswer((_) async {});
  });

  Future<void> pump(WidgetTester tester, ComplaintState state) {
    when(() => harness.complaint.state).thenReturn(state);
    return harness.pump(tester, const ComplaintView());
  }

  Finder submit() =>
      find.widgetWithText(FilledButton, l10n.complaintSubmit('ms'));

  testWidgets('asks what happened, with every reason', (tester) async {
    await pump(tester, const ComplaintState());

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.complaintTitle), findsOneWidget);
    expect(find.text(l10n.complaintQuestion), findsOneWidget);
    for (final reason in [
      l10n.complaintReasonNoShow,
      l10n.complaintReasonPriceRaised,
      l10n.complaintReasonPoorWork,
      l10n.complaintReasonBadConduct,
      l10n.complaintReasonOther,
    ]) {
      expect(find.text(reason), findsOneWidget);
    }
    expect(find.text(l10n.complaintDetails), findsOneWidget);
    expect(tester.widget<FilledButton>(submit()).onPressed, isNull);
  });

  testWidgets('names the request and technician once fetched', (
    tester,
  ) async {
    await pump(
      tester,
      ComplaintState(request: testRequestDetails(job: testRequestJob())),
    );

    expect(
      find.text(l10n.complaintSubtitle('تكييف مش بيبرّد', 'محمود السيد')),
      findsOneWidget,
    );
  });

  testWidgets('picks a reason', (tester) async {
    await pump(tester, const ComplaintState());

    await tester.tap(find.text(l10n.complaintReasonPriceRaised));

    verify(
      () => harness.complaint.pickReason(ComplaintReason.priceRaised),
    ).called(1);
  });

  testWidgets('sends the reason with the details typed', (tester) async {
    await pump(tester, const ComplaintState(reason: ComplaintReason.other));

    await tester.enterText(find.byType(TextField), 'قالي جاي وماجاش');
    await tester.tap(submit());

    verify(
      () => harness.complaint.send(details: 'قالي جاي وماجاش'),
    ).called(1);
  });

  testWidgets('shows the complaint being sent', (tester) async {
    await pump(
      tester,
      const ComplaintState(
        reason: ComplaintReason.other,
        status: ComplaintStatus.sending,
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    verifyNever(() => harness.complaint.send(details: any(named: 'details')));
  });

  testWidgets('closes with true once sent', (tester) async {
    when(() => harness.complaint.state).thenReturn(
      const ComplaintState(reason: ComplaintReason.other),
    );
    whenListen(
      harness.complaint,
      Stream.value(
        const ComplaintState(
          reason: ComplaintReason.other,
          status: ComplaintStatus.sent,
        ),
      ),
      initialState: const ComplaintState(reason: ComplaintReason.other),
    );
    bool? result;
    await harness.pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.of(context).push(
            MaterialPageRoute<bool>(builder: (_) => const ComplaintView()),
          ),
          child: const Text('open'),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(result, isTrue);
    expect(find.byType(ComplaintView), findsNothing);
  });

  group('failures', () {
    for (final (name, failure, message) in [
      (
        'a complaint already open',
        const AlreadySentFailure(),
        l10n.complaintOpen,
      ),
      (
        'too many photos today',
        const UploadLimitFailure(),
        l10n.complaintPhotoLimit('ms'),
      ),
      ('no network', const NetworkFailure(), l10n.consumerErrorNetwork('ms')),
    ]) {
      testWidgets('says so for $name', (tester) async {
        const editing = ComplaintState(reason: ComplaintReason.other);
        whenListen(
          harness.complaint,
          Stream.value(
            ComplaintState(reason: ComplaintReason.other, failure: failure),
          ),
          initialState: editing,
        );
        await harness.pump(tester, const ComplaintView());
        await tester.pump();

        expect(find.text(message), findsOneWidget);
      });
    }
  });

  group('photo', () {
    testWidgets('attaches one from the gallery', (tester) async {
      when(
        () => harness.photoPicker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenAnswer((_) async => '/tmp/complaint.jpg');
      await pump(tester, const ComplaintState());

      await reveal(tester, find.text(l10n.complaintAddPhoto('ms')));
      await tester.tap(find.text(l10n.complaintAddPhoto('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.complaintPhotoChoose('ms')));
      await tester.pumpAndSettle();

      verify(
        () => harness.photoPicker.pick(
          source: PhotoSource.gallery,
          purpose: PhotoPurpose.job,
        ),
      ).called(1);
      verify(
        () => harness.complaint.attachPhoto('/tmp/complaint.jpg'),
      ).called(1);
    });

    testWidgets('attaches nothing when picking is called off', (
      tester,
    ) async {
      when(
        () => harness.photoPicker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenAnswer((_) async => null);
      await pump(tester, const ComplaintState());

      await reveal(tester, find.text(l10n.complaintAddPhoto('ms')));
      await tester.tap(find.text(l10n.complaintAddPhoto('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.complaintPhotoTake('ms')));
      await tester.pumpAndSettle();

      verifyNever(() => harness.complaint.attachPhoto(any()));
    });

    testWidgets('says when the camera is not allowed', (tester) async {
      when(
        () => harness.photoPicker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenThrow(PlatformException(code: 'camera_access_denied'));
      await pump(tester, const ComplaintState());

      await reveal(tester, find.text(l10n.complaintAddPhoto('ms')));
      await tester.tap(find.text(l10n.complaintAddPhoto('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.complaintPhotoTake('ms')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.complaintPhotoDenied('ms')), findsOneWidget);
    });

    testWidgets('shows the attached photo and removes it', (tester) async {
      await pump(tester, const ComplaintState(photo: '/tmp/missing.jpg'));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.complaintAddPhoto('ms')), findsNothing);
      await reveal(tester, find.byTooltip(l10n.complaintPhotoRemove('ms')));
      await tester.tap(find.byTooltip(l10n.complaintPhotoRemove('ms')));

      verify(harness.complaint.removePhoto).called(1);
    });
  });

  testWidgets('speaks to a man as a man', (tester) async {
    harness = FollowUpHarness(honorific: Honorific.mr);
    await pump(tester, const ComplaintState());

    await reveal(tester, find.text(l10n.complaintAddPhoto('mr')));
    expect(find.text(l10n.complaintSubmit('mr')), findsOneWidget);
  });
}
