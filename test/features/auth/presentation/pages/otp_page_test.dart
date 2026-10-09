import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/presentation/cubit/otp_cubit.dart';
import 'package:salahly/features/auth/presentation/pages/otp_page.dart';
import 'package:salahly/features/auth/presentation/widgets/otp_code_boxes.dart';
import 'package:salahly/features/auth/presentation/widgets/otp_keypad.dart';

import '../../../../pump_app.dart';

class _MockOtpCubit extends MockCubit<OtpState> implements OtpCubit {}

void main() {
  late OtpCubit cubit;

  setUpAll(loadAppFonts);

  setUp(() {
    cubit = _MockOtpCubit();
    when(() => cubit.phone).thenReturn(PhoneNumber.tryParse('1002345678')!);
    when(() => cubit.channel).thenReturn(OtpChannel.whatsapp);
    when(() => cubit.state).thenReturn(const OtpState());
    when(() => cubit.verify()).thenAnswer((_) async {});
    when(() => cubit.resend()).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const OtpPage(),
    blocs: [BlocProvider<OtpCubit>.value(value: cubit)],
  );

  Finder keypadKey(String label) => find.descendant(
    of: find.byType(OtpKeypad),
    matching: find.text(label),
  );

  group('OtpPage', () {
    testWidgets('fits a small phone and says where the code went', (
      tester,
    ) async {
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.otpTitle), findsOneWidget);
      expect(
        find.textContaining(l10n.otpSentWhatsapp, findRichText: true),
        findsOneWidget,
      );
      expect(
        find.textContaining('+20 100 234 5678', findRichText: true),
        findsOneWidget,
      );
      expect(find.text(l10n.otpOpenWhatsapp), findsOneWidget);
    });

    testWidgets('fits a small phone with the largest system font', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await pumpPage(tester);

      expect(tester.takeException(), isNull);
    });

    testWidgets('passes keypad taps to the cubit', (tester) async {
      await pumpPage(tester);

      await tester.tap(keypadKey('7'));
      await tester.tap(keypadKey('0'));
      await tester.tap(find.bySemanticsLabel(l10n.otpDeleteDigit));

      verifyInOrder([
        () => cubit.digitEntered('7'),
        () => cubit.digitEntered('0'),
        () => cubit.digitDeleted(),
      ]);
    });

    testWidgets('shows the digits entered so far', (tester) async {
      when(() => cubit.state).thenReturn(const OtpState(code: '482'));

      await pumpPage(tester);

      for (final digit in ['4', '8', '2']) {
        expect(
          find.descendant(
            of: find.byType(OtpCodeBoxes),
            matching: find.text(digit),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('counts down to the next resend in minutes and seconds', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(const OtpState(resendIn: 5));

      await pumpPage(tester);

      expect(find.text(l10n.otpResendIn('0:05')), findsOneWidget);
      expect(find.text(l10n.otpResend), findsNothing);
    });

    testWidgets('starts the countdown at one minute', (tester) async {
      await pumpPage(tester);

      expect(find.text(l10n.otpResendIn('1:00')), findsOneWidget);
    });

    testWidgets('resends the code once the countdown ends', (tester) async {
      when(() => cubit.state).thenReturn(const OtpState(resendIn: 0));
      await pumpPage(tester);

      await tester.tap(find.text(l10n.otpResend));

      verify(() => cubit.resend()).called(1);
    });

    testWidgets('keeps submit disabled until the code is complete', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(const OtpState(code: '12345'));
      await pumpPage(tester);

      await tester.tap(find.text(l10n.otpSubmit));

      verifyNever(() => cubit.verify());
    });

    testWidgets('submits a complete code', (tester) async {
      when(() => cubit.state).thenReturn(const OtpState(code: '123456'));
      await pumpPage(tester);

      await tester.tap(find.text(l10n.otpSubmit));

      verify(() => cubit.verify()).called(1);
    });

    testWidgets('explains a wrong or expired code', (tester) async {
      when(
        () => cubit.state,
      ).thenReturn(const OtpState(failure: InvalidOtpFailure()));

      await pumpPage(tester);

      expect(find.text(l10n.otpInvalid), findsOneWidget);
    });

    testWidgets('confirms a resent code', (tester) async {
      whenListen(
        cubit,
        Stream.value(const OtpState(resendCount: 1)),
        initialState: const OtpState(),
      );

      await pumpPage(tester);
      await tester.pump();

      expect(find.text(l10n.otpResent), findsOneWidget);
    });

    testWidgets('leaves out the WhatsApp shortcut for an SMS code', (
      tester,
    ) async {
      when(() => cubit.channel).thenReturn(OtpChannel.sms);

      await pumpPage(tester);

      expect(
        find.textContaining(l10n.otpSentSms, findRichText: true),
        findsOneWidget,
      );
      expect(find.text(l10n.otpOpenWhatsapp), findsNothing);
    });
  });
}
