import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/auth/domain/entities/otp_channel.dart';
import 'package:salahly/features/auth/domain/failures/auth_failures.dart';
import 'package:salahly/features/auth/presentation/cubit/phone_cubit.dart';
import 'package:salahly/features/auth/presentation/pages/phone_page.dart';

import '../../../../pump_app.dart';

class _MockPhoneCubit extends MockCubit<PhoneState> implements PhoneCubit {}

void main() {
  late PhoneCubit cubit;

  setUpAll(() async {
    registerFallbackValue(OtpChannel.whatsapp);
    await loadAppFonts();
  });

  setUp(() {
    cubit = _MockPhoneCubit();
    when(() => cubit.state).thenReturn(const PhoneState());
    when(() => cubit.sendCode(any())).thenAnswer((_) async {});
  });

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const PhonePage(),
    blocs: [BlocProvider<PhoneCubit>.value(value: cubit)],
    stubRoutes: [AppRoutes.otp],
  );

  group('PhonePage', () {
    testWidgets('fits a small phone, right to left', (tester) async {
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.phoneTitle), findsOneWidget);
      expect(find.text(l10n.phoneHint), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(l10n.phoneTitle))),
        TextDirection.rtl,
      );
    });

    testWidgets('groups the typed number and passes it to the cubit', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.enterText(find.byType(TextField), '٠١٠٠٢٣٤٥٦٧٨');

      expect(find.text('100 234 5678'), findsOneWidget);
      verify(() => cubit.numberChanged('100 234 5678')).called(1);
    });

    testWidgets('sends the code on WhatsApp', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.phoneSendWhatsapp));

      verify(() => cubit.sendCode(OtpChannel.whatsapp)).called(1);
    });

    testWidgets('sends the code by SMS', (tester) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.phoneSendSms));

      verify(() => cubit.sendCode(OtpChannel.sms)).called(1);
    });

    testWidgets('shows the invalid number error once send is tapped', (
      tester,
    ) async {
      final states = StreamController<PhoneState>();
      addTearDown(states.close);
      whenListen(
        cubit,
        states.stream,
        initialState: const PhoneState(digits: '123'),
      );
      when(() => cubit.sendCode(OtpChannel.whatsapp)).thenAnswer(
        (_) async => states.add(
          const PhoneState(digits: '123', showInvalid: true),
        ),
      );
      await pumpPage(tester);
      expect(find.text(l10n.phoneInvalid), findsNothing);

      await tester.tap(find.text(l10n.phoneSendWhatsapp));
      await tester.pump();

      expect(find.text(l10n.phoneInvalid), findsOneWidget);
      expect(find.text(l10n.phoneHint), findsNothing);
    });

    testWidgets('suggests SMS when WhatsApp could not deliver the code', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const PhoneState(
          digits: '1002345678',
          failure: OtpDeliveryFailure(),
        ),
      );

      await pumpPage(tester);

      expect(find.text(l10n.otpDeliveryFailedWhatsapp), findsOneWidget);
    });

    testWidgets('ignores both buttons while a code is being sent', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(
        const PhoneState(digits: '1002345678', status: PhoneStatus.sending),
      );
      await pumpPage(tester);

      await tester.tap(find.byType(FilledButton));
      await tester.tap(find.text(l10n.phoneSendSms));

      expect(find.text(l10n.phoneSendWhatsapp), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      verifyNever(() => cubit.sendCode(any()));
    });

    testWidgets('opens the code screen once the code is sent', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.value(
          const PhoneState(
            digits: '1002345678',
            status: PhoneStatus.codeSent,
          ),
        ),
        initialState: const PhoneState(digits: '1002345678'),
      );

      await pumpPage(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.otp), findsOneWidget);
    });
  });
}
