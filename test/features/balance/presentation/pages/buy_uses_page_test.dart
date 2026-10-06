import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/upload_failures.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/widgets/dashed_rrect_border.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/failures/balance_failures.dart';
import 'package:salahly/features/balance/presentation/cubit/buy_uses_cubit.dart';
import 'package:salahly/features/balance/presentation/pages/buy_uses_page.dart';

import '../../../../helpers/balance_fixtures.dart';
import '../../../../helpers/balance_harness.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    BalanceHarness.registerFallbacks();
  });

  const consumerState = BuyUsesState(
    status: BuyUsesStatus.editing,
    packs: consumerPacks,
    accounts: paymentAccounts,
    packId: 'pack-5',
    method: TopupMethod.instapay,
  );
  final technicianState = consumerState.copyWith(
    packs: technicianPacks,
    packId: 'pack-t10',
  );
  final filled = consumerState.copyWith(
    sender: '0111 456 7720',
    screenshot: () => '/tmp/proof.jpg',
  );

  BalanceHarness consumer({
    Honorific honorific = Honorific.ms,
    int credits = 0,
  }) => BalanceHarness(
    session: consumerWithCredits(honorific: honorific, credits: credits),
  );

  BalanceHarness technician({int credits = 0}) =>
      BalanceHarness(session: technicianSession(credits: credits));

  /// On a tall screen, so every step is on it; [smallPhone] tests scroll.
  Future<void> pump(
    WidgetTester tester,
    BalanceHarness harness,
    BuyUsesState state, {
    UserRole role = UserRole.consumer,
    Size surfaceSize = const Size(360, 1400),
  }) {
    when(() => harness.buyUses.state).thenReturn(state);
    return harness.pump(
      tester,
      BuyUsesView(role: role),
      surfaceSize: surfaceSize,
    );
  }

  Finder submit(String label) => find.widgetWithText(FilledButton, label);

  group('for a consumer', () {
    testWidgets('shows the steps, the packs and where to send the money', (
      tester,
    ) async {
      await pump(tester, consumer(), consumerState);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.buyUsesTitleConsumer('ms')), findsOneWidget);
      expect(find.text(l10n.buyUsesStepPack('ms')), findsOneWidget);
      expect(find.text(l10n.buyUsesStepTransfer('ms', '80')), findsOneWidget);
      expect(find.text(l10n.buyUsesStepSender('ms')), findsOneWidget);
      expect(find.text(l10n.buyUsesStepScreenshot('ms')), findsOneWidget);
      for (final number in ['1', '2', '3', '4']) {
        expect(find.text(number), findsOneWidget);
      }
      expect(find.text(l10n.buyUsesPackConsumer(1)), findsOneWidget);
      expect(find.text(l10n.buyUsesPackConsumer(5)), findsOneWidget);
      expect(find.text(l10n.pounds('20')), findsOneWidget);
      expect(find.text(l10n.pounds('80')), findsOneWidget);
      expect(find.text(l10n.buyUsesNoteSingleConsumer), findsOneWidget);
      expect(
        find.text(l10n.buyUsesNoteSavingConsumer('ms', '16', '20')),
        findsOneWidget,
      );
      expect(find.text('salahly@instapay'), findsOneWidget);
      expect(find.text(l10n.buyUsesHolder('شركة صلحلي')), findsOneWidget);
      expect(find.text(l10n.buyUsesAccountInstapay), findsOneWidget);
    });

    testWidgets('says all the free requests are used when none are left', (
      tester,
    ) async {
      await pump(tester, consumer(), consumerState);

      expect(find.text(l10n.buyUsesConsumerIntroNone('ms')), findsOneWidget);
      expect(find.text(l10n.buyUsesConsumerIntroBody('ms')), findsOneWidget);
    });

    testWidgets('says how many are left when there are some', (tester) async {
      await pump(tester, consumer(credits: 1), consumerState);

      expect(
        find.text(
          '${l10n.consumerHomeCreditsLead('ms')} '
          '${l10n.consumerHomeCreditsCount(1)}',
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.buyUsesConsumerIntroNone('ms')), findsNothing);
    });

    testWidgets('speaks to a man as a man', (tester) async {
      await pump(tester, consumer(honorific: Honorific.mr), consumerState);

      expect(find.text(l10n.buyUsesTitleConsumer('mr')), findsOneWidget);
      expect(find.text(l10n.buyUsesStepPack('mr')), findsOneWidget);
      expect(find.text(l10n.buyUsesConsumerIntroNone('mr')), findsOneWidget);
      expect(
        find.text(l10n.buyUsesNoteSavingConsumer('mr', '16', '20')),
        findsOneWidget,
      );
      expect(find.text(l10n.buyUsesSubmit('mr')), findsOneWidget);
      expect(find.text(l10n.buyUsesTitleConsumer('ms')), findsNothing);
    });

    testWidgets('shows no savings for a pack that saves nothing', (
      tester,
    ) async {
      await pump(
        tester,
        consumer(),
        consumerState.copyWith(
          packs: const [
            CreditPack(id: 'pack-1', uses: 1, pricePiastres: 2000),
            CreditPack(id: 'pack-5', uses: 5, pricePiastres: 10000),
          ],
        ),
      );

      expect(find.text(l10n.buyUsesNotePerUseConsumer('20')), findsOneWidget);
    });
  });

  group('on the smallest phone', () {
    for (final (name, role) in [
      ('consumer', UserRole.consumer),
      ('technician', UserRole.technician),
    ]) {
      testWidgets('fits for a $name, down to the screenshot', (tester) async {
        final harness = role == UserRole.consumer ? consumer() : technician();
        await pump(
          tester,
          harness,
          role == UserRole.consumer ? consumerState : technicianState,
          role: role,
          surfaceSize: smallPhone,
        );
        await tester.scrollUntilVisible(
          find.byType(DashedRRectBorder),
          200,
          scrollable: find.byType(Scrollable).first,
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(FilledButton), findsOneWidget);
      });
    }
  });

  group('for a technician', () {
    testWidgets('shows the same steps in the technician words', (
      tester,
    ) async {
      await pump(
        tester,
        technician(),
        technicianState,
        role: UserRole.technician,
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.buyUsesTitleTechnician), findsOneWidget);
      expect(find.text(l10n.buyUsesStepPack('other')), findsOneWidget);
      expect(find.text(l10n.buyUsesPackTechnician(1)), findsOneWidget);
      expect(find.text(l10n.buyUsesPackTechnician(10)), findsOneWidget);
      expect(find.text(l10n.buyUsesNoteSingleTechnician), findsOneWidget);
      expect(
        find.text(l10n.buyUsesNoteSavingTechnician('25', '50')),
        findsOneWidget,
      );
      expect(
        find.text(l10n.buyUsesStepTransfer('other', '250')),
        findsOneWidget,
      );
      expect(find.text(l10n.buyUsesSubmit('other')), findsOneWidget);
    });

    testWidgets('says the free jobs are gone and the balance is zero', (
      tester,
    ) async {
      await pump(
        tester,
        technician(),
        technicianState,
        role: UserRole.technician,
      );

      expect(find.text(l10n.buyUsesTechnicianIntroNone), findsOneWidget);
      expect(
        find.text(l10n.buyUsesTechnicianIntroBody(0)),
        findsOneWidget,
      );
      expect(find.textContaining('1,000'), findsOneWidget);
    });

    testWidgets('says how many jobs are left when there are some', (
      tester,
    ) async {
      await pump(
        tester,
        technician(credits: 1),
        technicianState,
        role: UserRole.technician,
      );

      expect(find.text(l10n.todayRequestsCreditsLeft(1)), findsOneWidget);
      expect(
        find.text(l10n.buyUsesTechnicianIntroBody(1)),
        findsOneWidget,
      );
      expect(find.text(l10n.buyUsesTechnicianIntroNone), findsNothing);
    });
  });

  group('the transfer', () {
    testWidgets('picks a pack', (tester) async {
      final harness = consumer();
      await pump(tester, harness, consumerState);

      await tester.tap(find.text(l10n.buyUsesPackConsumer(1)));

      verify(() => harness.buyUses.pickPack('pack-1')).called(1);
    });

    testWidgets('switches between InstaPay and the wallet', (tester) async {
      final harness = consumer();
      await pump(tester, harness, consumerState);

      await tester.tap(find.text(l10n.buyUsesMethodWallet));

      verify(() => harness.buyUses.pickMethod(TopupMethod.wallet)).called(1);
    });

    testWidgets('shows the wallet account when it is picked', (tester) async {
      await pump(
        tester,
        consumer(),
        consumerState.copyWith(method: TopupMethod.wallet),
      );

      expect(find.text('01000000000'), findsOneWidget);
      expect(find.text(l10n.buyUsesAccountWallet), findsOneWidget);
    });

    testWidgets('offers only the methods that have an account', (
      tester,
    ) async {
      await pump(
        tester,
        consumer(),
        consumerState.copyWith(accounts: [paymentAccounts.first]),
      );

      expect(find.text(l10n.buyUsesMethodInstapay), findsOneWidget);
      expect(find.text(l10n.buyUsesMethodWallet), findsNothing);
    });

    testWidgets('copies the account and says so', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied =
                (call.arguments as Map<Object?, Object?>)['text']! as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await pump(tester, consumer(), consumerState);

      await tester.tap(find.text(l10n.buyUsesCopy('ms')));
      await tester.pump();

      expect(copied, 'salahly@instapay');
      expect(find.text(l10n.buyUsesCopied), findsOneWidget);
    });

    testWidgets('passes what is typed as the sender', (tester) async {
      final harness = consumer();
      await pump(tester, harness, consumerState);

      await tester.enterText(find.byType(TextField), '٠١١١٤٥٦٧٧٢٠');

      verify(() => harness.buyUses.setSender('٠١١١٤٥٦٧٧٢٠')).called(1);
    });

    testWidgets('lets only digits into a wallet number', (tester) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        consumerState.copyWith(method: TopupMethod.wallet),
      );

      await tester.enterText(find.byType(TextField), '01a1 4-5');

      verify(() => harness.buyUses.setSender('01145')).called(1);
    });

    testWidgets('says a wrong wallet number only after leaving the field', (
      tester,
    ) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        consumerState.copyWith(method: TopupMethod.wallet, sender: '0111'),
      );
      await tester.enterText(find.byType(TextField), '0111');
      expect(find.text(l10n.buyUsesSenderInvalidWallet('ms')), findsNothing);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(find.text(l10n.buyUsesSenderInvalidWallet('ms')), findsOneWidget);
    });

    testWidgets('says a wrong InstaPay account the InstaPay way', (
      tester,
    ) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        consumerState.copyWith(sender: 'ab'),
      );
      await tester.enterText(find.byType(TextField), 'ab');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();

      expect(
        find.text(l10n.buyUsesSenderInvalidInstapay('ms')),
        findsOneWidget,
      );
    });
  });

  group('the screenshot', () {
    testWidgets('is picked from the gallery and handed over', (tester) async {
      final harness = consumer();
      await pump(tester, harness, consumerState);

      await tester.tap(find.text(l10n.buyUsesScreenshotAdd('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.complaintPhotoChoose('ms')));
      await tester.pumpAndSettle();

      verify(
        () => harness.photoPicker.pick(
          source: PhotoSource.gallery,
          purpose: PhotoPurpose.transfer,
        ),
      ).called(1);
      verify(
        () => harness.buyUses.attachScreenshot('/tmp/proof.jpg'),
      ).called(1);
    });

    testWidgets('can be taken with the camera', (tester) async {
      final harness = consumer();
      await pump(tester, harness, consumerState);

      await tester.tap(find.text(l10n.buyUsesScreenshotAdd('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.complaintPhotoTake('ms')));
      await tester.pumpAndSettle();

      verify(
        () => harness.photoPicker.pick(
          source: PhotoSource.camera,
          purpose: PhotoPurpose.transfer,
        ),
      ).called(1);
    });

    testWidgets('attaches nothing when picking is cancelled', (tester) async {
      final harness = consumer();
      when(
        () => harness.photoPicker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenAnswer((_) async => null);
      await pump(tester, harness, consumerState);

      await tester.tap(find.text(l10n.buyUsesScreenshotAdd('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.complaintPhotoChoose('ms')));
      await tester.pumpAndSettle();

      verifyNever(() => harness.buyUses.attachScreenshot(any()));
    });

    testWidgets('says when the camera is not allowed', (tester) async {
      final harness = consumer();
      when(
        () => harness.photoPicker.pick(
          source: any(named: 'source'),
          purpose: any(named: 'purpose'),
        ),
      ).thenThrow(PlatformException(code: 'camera_access_denied'));
      await pump(tester, harness, consumerState);

      await tester.tap(find.text(l10n.buyUsesScreenshotAdd('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.complaintPhotoTake('ms')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.complaintPhotoDenied('ms')), findsOneWidget);
    });

    testWidgets('shows what was picked, with a way to change it', (
      tester,
    ) async {
      final harness = consumer();
      await pump(tester, harness, filled);

      expect(find.text(l10n.buyUsesScreenshotChosen), findsOneWidget);
      expect(find.text(l10n.buyUsesScreenshotAdd('ms')), findsNothing);

      await tester.tap(find.text(l10n.buyUsesScreenshotChange));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.complaintPhotoChoose('ms')));
      await tester.pumpAndSettle();

      verify(
        () => harness.buyUses.attachScreenshot('/tmp/proof.jpg'),
      ).called(1);
    });
  });

  group('sending', () {
    testWidgets('waits until everything is filled in', (tester) async {
      final harness = consumer();
      await pump(tester, harness, consumerState);

      final button = tester.widget<FilledButton>(
        submit(l10n.buyUsesSubmit('ms')),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('sends for review once everything is filled in', (
      tester,
    ) async {
      final harness = consumer();
      await pump(tester, harness, filled);

      await tester.tap(submit(l10n.buyUsesSubmit('ms')));

      verify(harness.buyUses.submit).called(1);
    });

    testWidgets('shows the transfer being sent', (tester) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        filled.copyWith(status: BuyUsesStatus.submitting),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      verifyNever(harness.buyUses.submit);
    });

    testWidgets('thanks, refreshes the balance and closes once sent', (
      tester,
    ) async {
      final harness = consumer();
      when(() => harness.buyUses.state).thenReturn(filled);
      whenListen(
        harness.buyUses,
        Stream.value(filled.copyWith(status: BuyUsesStatus.submitted)),
        initialState: filled,
      );
      bool? result;
      await harness.pump(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => const BuyUsesView(role: UserRole.consumer),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(result, isTrue);
      expect(find.text(l10n.buyUsesSent), findsOneWidget);
      verify(harness.session.refreshProfile).called(1);
    });

    for (final (name, failure, message) in <(String, Failure, String)>[
      (
        'too many waiting',
        const TooManyPendingFailure(),
        l10n.buyUsesTooManyPending('ms'),
      ),
      (
        'a pack that is gone',
        const PackNotFoundFailure(),
        l10n.buyUsesPackGone('ms'),
      ),
      (
        'a method that is gone',
        const MethodUnavailableFailure(),
        l10n.buyUsesMethodGone('ms'),
      ),
      (
        'a refused sender',
        const InvalidSenderFailure(),
        l10n.buyUsesInvalidSender('ms'),
      ),
      (
        'a refused screenshot',
        const InvalidScreenshotFailure(),
        l10n.buyUsesInvalidScreenshot('ms'),
      ),
      (
        'the upload limit',
        const UploadLimitFailure(),
        l10n.buyUsesUploadLimit('ms'),
      ),
      (
        'a file that is not an image',
        const UnsupportedPhotoFailure(),
        l10n.buyUsesPhotoRejected('ms'),
      ),
      ('no network', const NetworkFailure(), l10n.consumerErrorNetwork('ms')),
      (
        'anything else',
        const UnexpectedFailure(),
        l10n.consumerErrorUnexpected('ms'),
      ),
    ]) {
      testWidgets('tells a consumer about $name', (tester) async {
        final harness = consumer();
        when(() => harness.buyUses.state).thenReturn(filled);
        whenListen(
          harness.buyUses,
          Stream.value(filled.copyWith(failure: () => failure)),
          initialState: filled,
        );
        await harness.pump(tester, const BuyUsesView(role: UserRole.consumer));
        await tester.pump();

        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('tells a technician in the technician words', (tester) async {
      final harness = technician();
      when(() => harness.buyUses.state).thenReturn(technicianState);
      whenListen(
        harness.buyUses,
        Stream.value(
          technicianState.copyWith(failure: () => const NetworkFailure()),
        ),
        initialState: technicianState,
      );
      await harness.pump(
        tester,
        const BuyUsesView(role: UserRole.technician),
      );
      await tester.pump();

      expect(find.text(l10n.errorNetwork), findsOneWidget);
    });
  });

  group('before the packs are there', () {
    testWidgets('waits for them', (tester) async {
      await pump(tester, consumer(), const BuyUsesState());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text(l10n.buyUsesTitleConsumer('ms')), findsOneWidget);
    });

    testWidgets('says when they could not be fetched, and retries', (
      tester,
    ) async {
      final harness = consumer();
      await pump(
        tester,
        harness,
        const BuyUsesState(status: BuyUsesStatus.failed),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.buyUsesUnavailable('ms')), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);

      await tester.tap(find.text(l10n.retry));

      verify(harness.buyUses.load).called(1);
    });
  });
}
