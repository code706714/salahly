import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/calls/presentation/cubit/call_cubit.dart';
import 'package:salahly/features/calls/presentation/pages/call_page.dart';

import '../../../../pump_app.dart';

class MockCallCubit extends MockCubit<CallState> implements CallCubit {}

void main() {
  late MockCallCubit cubit;

  setUpAll(loadAppFonts);

  setUp(() {
    cubit = MockCallCubit();
    when(cubit.hangUp).thenAnswer((_) async {});
    when(cubit.accept).thenAnswer((_) async {});
    when(cubit.decline).thenAnswer((_) async {});
    when(cubit.toggleSpeaker).thenAnswer((_) async {});
    when(cubit.toggleMute).thenReturn(null);
  });

  Future<void> show(WidgetTester tester, CallState state) {
    when(() => cubit.state).thenReturn(state);
    return tester.pumpApp(
      const CallView(name: 'نورهان م.'),
      blocs: [BlocProvider<CallCubit>.value(value: cubit)],
    );
  }

  testWidgets('shows who is called while it rings, with a hang-up button', (
    tester,
  ) async {
    await show(tester, const CallState(phase: CallPhase.ringing));

    expect(find.text('نورهان م.'), findsOneWidget);
    expect(find.text(l10n.callRinging), findsOneWidget);
    expect(find.text(l10n.callSafetyNote), findsOneWidget);

    await tester.tap(find.byIcon(Icons.call_end_rounded));
    verify(cubit.hangUp).called(1);
  });

  testWidgets('offers to answer or turn down a call coming in', (
    tester,
  ) async {
    await show(tester, const CallState(phase: CallPhase.incoming));

    expect(find.text(l10n.callIncoming), findsOneWidget);
    await tester.tap(find.byIcon(Icons.call_rounded));
    verify(cubit.accept).called(1);
    await tester.tap(find.byIcon(Icons.call_end_rounded));
    verify(cubit.decline).called(1);
  });

  testWidgets('shows the time once connected, and mutes and loudspeaks', (
    tester,
  ) async {
    await show(
      tester,
      const CallState(phase: CallPhase.connected, seconds: 75),
    );

    expect(find.text('01:15'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    verify(cubit.toggleMute).called(1);
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    verify(cubit.toggleSpeaker).called(1);
  });

  testWidgets('says the microphone is off when muted', (tester) async {
    await show(
      tester,
      const CallState(phase: CallPhase.connected, muted: true),
    );

    expect(find.text(l10n.callUnmute), findsOneWidget);
  });

  testWidgets('says why a call ended and drops the controls', (tester) async {
    await show(
      tester,
      const CallState(phase: CallPhase.ended, end: CallEnd.missed),
    );

    expect(find.text(l10n.callEndedMissed), findsOneWidget);
    expect(find.text(l10n.callHangUp), findsNothing);
    expect(find.text(l10n.callSafetyNote), findsNothing);
    expect(find.text(l10n.callDone), findsOneWidget);
  });

  testWidgets('says every reason a call can end', (tester) async {
    for (final end in CallEnd.values) {
      await show(tester, CallState(phase: CallPhase.ended, end: end));
      expect(find.text(l10n.callDone), findsOneWidget, reason: '$end');
    }
  });
}
