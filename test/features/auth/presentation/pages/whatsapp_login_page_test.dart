import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/auth/domain/entities/whatsapp_login.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/presentation/cubit/whatsapp_login_cubit.dart';
import 'package:salahly/features/auth/presentation/pages/whatsapp_login_page.dart';

import '../../../../pump_app.dart';

class _MockWhatsappLoginCubit extends MockCubit<WhatsappLoginState>
    implements WhatsappLoginCubit {}

void main() {
  final challenge = WhatsappLoginChallenge(
    id: '11111111-2222-4333-8444-555555555555',
    code: 'AB3D5FGH',
    pollSecret: 'a' * 64,
    expiresAt: DateTime.utc(2026, 10, 14, 12),
    whatsappNumber: PhoneNumber.tryParse('1000000000')!,
  );
  late WhatsappLoginCubit cubit;

  setUpAll(() async {
    registerFallbackValue((String code) => code);
    await loadAppFonts();
  });

  setUp(() {
    cubit = _MockWhatsappLoginCubit();
    when(() => cubit.state).thenReturn(const WhatsappLoginState());
    when(() => cubit.start(any())).thenAnswer((_) async {});
    when(() => cubit.openWhatsapp()).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester, [WhatsappLoginState? state]) {
    if (state != null) when(() => cubit.state).thenReturn(state);
    return tester.pumpApp(
      const WhatsappLoginPage(),
      blocs: [BlocProvider<WhatsappLoginCubit>.value(value: cubit)],
    );
  }

  group('WhatsappLoginPage', () {
    testWidgets('fits a small phone, right to left', (tester) async {
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.whatsappLoginTitle), findsOneWidget);
      expect(find.text(l10n.whatsappLoginStepOpen), findsOneWidget);
      expect(find.text(l10n.whatsappLoginStepSend), findsOneWidget);
      expect(find.text(l10n.whatsappLoginStepBack), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(l10n.whatsappLoginTitle))),
        TextDirection.rtl,
      );
    });

    testWidgets('asks for no phone number', (tester) async {
      await pumpPage(tester);

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('the button starts the sign in with the message text', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.whatsappLoginStart));

      final writer =
          verify(() => cubit.start(captureAny())).captured.single
              as String Function(String);
      expect(writer('AB3D5FGH'), l10n.whatsappLoginMessage('AB3D5FGH'));
      expect(writer('AB3D5FGH'), contains('AB3D5FGH'));
    });

    testWidgets('shows the code and the way back while waiting', (
      tester,
    ) async {
      await pumpPage(
        tester,
        WhatsappLoginState(
          phase: WhatsappLoginPhase.waiting,
          challenge: challenge,
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('AB3D5FGH'), findsOneWidget);
      expect(find.text(l10n.whatsappLoginWaitingTitle), findsOneWidget);
      expect(find.text(l10n.whatsappLoginStart), findsNothing);

      await tester.tap(find.text(l10n.whatsappLoginReopen));
      verify(() => cubit.openWhatsapp()).called(1);

      await tester.tap(find.text(l10n.whatsappLoginCancel));
      verify(() => cubit.cancel()).called(1);
    });

    testWidgets('shows that it is signing in, with nothing else to press', (
      tester,
    ) async {
      await pumpPage(
        tester,
        WhatsappLoginState(
          phase: WhatsappLoginPhase.signingIn,
          challenge: challenge,
        ),
      );

      expect(find.text(l10n.whatsappLoginSigningIn), findsOneWidget);
      expect(find.text(l10n.whatsappLoginReopen), findsNothing);
      expect(find.text(l10n.whatsappLoginCancel), findsNothing);
    });

    testWidgets('an expired code can be retried', (tester) async {
      await pumpPage(
        tester,
        const WhatsappLoginState(phase: WhatsappLoginPhase.expired),
      );

      expect(find.text(l10n.whatsappLoginExpired), findsOneWidget);

      await tester.tap(find.text(l10n.whatsappLoginRetry));
      verify(() => cubit.start(any())).called(1);
    });

    testWidgets('says when WhatsApp did not open', (tester) async {
      await pumpPage(
        tester,
        WhatsappLoginState(
          phase: WhatsappLoginPhase.waiting,
          challenge: challenge,
          couldNotOpenWhatsapp: true,
        ),
      );

      expect(find.text(l10n.whatsappLoginOpenFailed), findsOneWidget);
    });

    final failures = <String, (Failure, String)>{
      'not set up': (
        const WhatsappLoginUnavailableFailure(),
        l10n.whatsappLoginUnavailable,
      ),
      'offline': (const NetworkFailure(), l10n.errorNetwork),
      'unexpected': (const UnexpectedFailure(), l10n.errorUnexpected),
    };
    for (final MapEntry(key: name, value: (failure, text))
        in failures.entries) {
      testWidgets('explains a failure: $name', (tester) async {
        await pumpPage(tester, WhatsappLoginState(failure: failure));

        expect(find.text(text), findsOneWidget);
      });
    }
  });
}
