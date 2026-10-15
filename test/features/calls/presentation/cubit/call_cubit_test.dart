import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/calls/domain/entities/call.dart';
import 'package:salahly/features/calls/domain/failures/call_failures.dart';
import 'package:salahly/features/calls/domain/services/call_engine.dart';
import 'package:salahly/features/calls/presentation/cubit/call_cubit.dart';

import '../../../../helpers/fake_call_engine.dart';
import '../../../../helpers/fake_call_ringer.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockCallRepository calls;
  late FakeCallEngine engine;
  late FakeCallRinger ringer;
  late StreamController<CallSignal> signals;
  late StreamController<CallStatus> statuses;

  setUpAll(() {
    registerFallbackValue(const CallSignalDraft(CallSignalKind.offer, {}));
  });

  setUp(() {
    calls = MockCallRepository();
    engine = FakeCallEngine();
    ringer = FakeCallRinger();
    signals = StreamController<CallSignal>.broadcast();
    statuses = StreamController<CallStatus>.broadcast();
    when(calls.iceServers).thenAnswer(
      (_) async => const [
        {'urls': 'stun:test'},
      ],
    );
    when(
      () => calls.start(any(), any()),
    ).thenAnswer((_) async => const Ok('c1'));
    when(() => calls.answer(any())).thenAnswer((_) async => const Ok(null));
    when(() => calls.end(any())).thenAnswer((_) async => const Ok(null));
    when(
      () => calls.sendSignal(any(), any()),
    ).thenAnswer((_) async => const Ok(null));
    when(() => calls.signals(any())).thenAnswer((_) => signals.stream);
    when(() => calls.statuses(any())).thenAnswer((_) => statuses.stream);
  });

  CallCubit making({Duration ringFor = const Duration(seconds: 45)}) =>
      CallCubit(
        calls: calls,
        engine: engine,
        ringer: ringer,
        requestId: 'r1',
        technicianId: 't1',
        ringFor: ringFor,
      );

  CallCubit makingWithConnectTimeout() => CallCubit(
    calls: calls,
    engine: engine,
    ringer: ringer,
    requestId: 'r1',
    technicianId: 't1',
    connectFor: const Duration(milliseconds: 20),
  );

  CallCubit taking({Duration ringFor = const Duration(seconds: 45)}) =>
      CallCubit(
        calls: calls,
        engine: engine,
        ringer: ringer,
        requestId: 'r1',
        technicianId: 't1',
        incomingCallId: 'c1',
        ringFor: ringFor,
      );

  Future<void> pump() => Future<void>.delayed(Duration.zero);

  group('making a call', () {
    test('rings the other side and makes the offer', () async {
      final cubit = making();
      await cubit.start();

      expect(cubit.state.phase, CallPhase.ringing);
      expect(engine.offered, isTrue);
      verify(() => calls.start('r1', 't1')).called(1);
      await cubit.close();
    });

    test('opens the engine with the servers the repository gives', () async {
      final cubit = making();
      await cubit.start();

      expect(engine.iceServers, [
        {'urls': 'stun:test'},
      ]);
      await cubit.close();
    });

    test(
      "passes the engine's handshake messages to the server in order",
      () async {
        final cubit = making();
        await cubit.start();
        const offer = CallSignalDraft(CallSignalKind.offer, {'sdp': 'a'});
        const route = CallSignalDraft(CallSignalKind.candidate, {'c': 'b'});

        engine.outgoingController
          ..add(offer)
          ..add(route);
        await pump();
        await pump();

        verifyInOrder([
          () => calls.sendSignal('c1', offer),
          () => calls.sendSignal('c1', route),
        ]);
        await cubit.close();
      },
    );

    test('passes what the other side sends to the engine', () async {
      final cubit = making();
      await cubit.start();
      const answer = CallSignal(
        id: 1,
        kind: CallSignalKind.answer,
        payload: {'sdp': 'x'},
      );

      signals.add(answer);
      await pump();
      await pump();

      expect(engine.received, [answer]);
      await cubit.close();
    });

    test('goes on to connecting when answered, then connected', () async {
      final cubit = making();
      await cubit.start();

      statuses.add(CallStatus.answered);
      await pump();
      expect(cubit.state.phase, CallPhase.connecting);

      engine.linkController.add(CallLink.connected);
      await pump();
      expect(cubit.state.phase, CallPhase.connected);
      await cubit.close();
    });

    test('counts the seconds once connected', () async {
      final cubit = making();
      await cubit.start();
      engine.linkController.add(CallLink.connected);
      await Future<void>.delayed(const Duration(milliseconds: 1100));

      expect(cubit.state.seconds, 1);
      await cubit.close();
    });

    test('ends as declined when the other side turns it down', () async {
      final cubit = making();
      await cubit.start();

      statuses.add(CallStatus.declined);
      await pump();

      expect(cubit.state.phase, CallPhase.ended);
      expect(cubit.state.end, CallEnd.declined);
      expect(engine.closed, isTrue);
      verifyNever(() => calls.end(any()));
    });

    test('ends as remote ended when the other side hangs up', () async {
      final cubit = making();
      await cubit.start();
      statuses.add(CallStatus.answered);
      await pump();

      statuses.add(CallStatus.ended);
      await pump();

      expect(cubit.state.end, CallEnd.remoteEnded);
    });

    test('hanging up tells the server and frees the microphone', () async {
      final cubit = making();
      await cubit.start();

      await cubit.hangUp();

      expect(cubit.state.end, CallEnd.hungUp);
      expect(engine.closed, isTrue);
      verify(() => calls.end('c1')).called(1);
    });

    test('gives up when nobody answers in time', () async {
      final cubit = making(ringFor: const Duration(milliseconds: 20));
      await cubit.start();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.end, CallEnd.missed);
      verify(() => calls.end('c1')).called(1);
    });

    test('fails when answered but the voice link never comes up', () async {
      final cubit = makingWithConnectTimeout();
      await cubit.start();
      statuses.add(CallStatus.answered);
      await pump();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.end, CallEnd.failed);
      verify(() => calls.end('c1')).called(1);
    });

    test('does not fail a link that came up in time', () async {
      final cubit = makingWithConnectTimeout();
      await cubit.start();
      statuses.add(CallStatus.answered);
      await pump();
      engine.linkController.add(CallLink.connected);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.phase, CallPhase.connected);
      await cubit.close();
    });

    test('ends when the link fails', () async {
      final cubit = making();
      await cubit.start();

      engine.linkController.add(CallLink.failed);
      await pump();

      expect(cubit.state.end, CallEnd.failed);
      verify(() => calls.end('c1')).called(1);
    });

    test('ends when the engine throws', () async {
      final failing = _ThrowingEngine();
      final cubit = CallCubit(
        calls: calls,
        engine: failing,
        ringer: ringer,
        requestId: 'r1',
        technicianId: 't1',
      );

      await cubit.start();

      expect(cubit.state.end, CallEnd.failed);
    });

    test('never rings when the microphone is not allowed', () async {
      engine.microphoneAllowed = false;
      final cubit = making();

      await cubit.start();

      expect(cubit.state.end, CallEnd.microphone);
      verifyNever(() => calls.start(any(), any()));
    });

    for (final (failure, end) in <(Failure, CallEnd)>[
      (const CalleeBusyFailure(), CallEnd.busy),
      (const CallInProgressFailure(), CallEnd.alreadyCalling),
      (const CallUnavailableFailure(), CallEnd.unavailable),
      (const NetworkFailure(), CallEnd.failed),
    ]) {
      test(
        'ends as $end when the server says ${failure.runtimeType}',
        () async {
          when(
            () => calls.start(any(), any()),
          ).thenAnswer((_) async => Err(failure));
          final cubit = making();

          await cubit.start();

          expect(cubit.state.end, end);
          verifyNever(() => calls.end(any()));
        },
      );
    }

    test('leaving the screen mid-call hangs up', () async {
      final cubit = making();
      await cubit.start();

      await cubit.close();

      verify(() => calls.end('c1')).called(1);
      expect(engine.closed, isTrue);
    });
  });

  group('taking a call', () {
    test('rings until answered or turned down', () async {
      final cubit = taking();
      await cubit.start();

      expect(cubit.state.phase, CallPhase.incoming);
      expect(engine.opened, isFalse);
      verifyNever(() => calls.answer(any()));
      await cubit.close();
    });

    test('answering opens the microphone and takes the handshake', () async {
      final cubit = taking();
      await cubit.start();

      await cubit.accept();
      const offer = CallSignal(
        id: 1,
        kind: CallSignalKind.offer,
        payload: {'sdp': 'x'},
      );
      signals.add(offer);
      await pump();
      await pump();

      expect(cubit.state.phase, CallPhase.connecting);
      expect(engine.opened, isTrue);
      expect(engine.received, [offer]);
      verify(() => calls.answer('c1')).called(1);
      await cubit.close();
    });

    test('declining tells the server', () async {
      final cubit = taking();
      await cubit.start();

      await cubit.decline();

      expect(cubit.state.end, CallEnd.declined);
      verify(() => calls.end('c1')).called(1);
    });

    test('stops ringing when the caller gives up', () async {
      final cubit = taking();
      await cubit.start();

      statuses.add(CallStatus.ended);
      await pump();

      expect(cubit.state.phase, CallPhase.ended);
      verifyNever(() => calls.end(any()));
    });

    test('stops ringing after the time is up', () async {
      final cubit = taking(ringFor: const Duration(milliseconds: 20));
      await cubit.start();

      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(cubit.state.end, CallEnd.missed);
    });

    test('hangs up on the caller when the microphone is not allowed', () async {
      engine.microphoneAllowed = false;
      final cubit = taking();
      await cubit.start();

      await cubit.accept();

      expect(cubit.state.end, CallEnd.microphone);
      verify(() => calls.end('c1')).called(1);
      verifyNever(() => calls.answer(any()));
    });

    test('ends when the call is gone by the time it is answered', () async {
      when(
        () => calls.answer(any()),
      ).thenAnswer((_) async => const Err(CallUnavailableFailure()));
      final cubit = taking();
      await cubit.start();

      await cubit.accept();

      expect(cubit.state.end, CallEnd.unavailable);
    });
  });

  group('the ring', () {
    test('a call made rings softly until answered', () async {
      final cubit = making();
      await cubit.start();
      expect(ringer.ringingIncoming, isFalse);

      statuses.add(CallStatus.answered);
      await pump();

      expect(ringer.ringingIncoming, isNull);
      await cubit.close();
    });

    test('a call coming in rings loudly until answered', () async {
      final cubit = taking();
      await cubit.start();
      expect(ringer.ringingIncoming, isTrue);

      await cubit.accept();

      expect(ringer.ringingIncoming, isNull);
      await cubit.close();
    });

    test('stops when the caller gives up', () async {
      final cubit = taking();
      await cubit.start();

      statuses.add(CallStatus.ended);
      await pump();

      expect(ringer.ringingIncoming, isNull);
    });

    test('stops when the call is turned down', () async {
      final cubit = taking();
      await cubit.start();

      await cubit.decline();

      expect(ringer.ringingIncoming, isNull);
    });

    test('stops when the screen closes', () async {
      final cubit = taking();
      await cubit.start();

      await cubit.close();

      expect(ringer.ringingIncoming, isNull);
    });
  });

  group('during a call', () {
    blocTest<CallCubit, CallState>(
      'mutes and unmutes the microphone',
      build: making,
      act: (cubit) async {
        await cubit.start();
        cubit
          ..toggleMute()
          ..toggleMute();
      },
      verify: (cubit) => expect(engine.muted, isFalse),
      expect: () => [
        const CallState(phase: CallPhase.ringing),
        const CallState(phase: CallPhase.ringing, muted: true),
        const CallState(phase: CallPhase.ringing),
      ],
    );

    blocTest<CallCubit, CallState>(
      'switches to the loudspeaker',
      build: making,
      act: (cubit) async {
        await cubit.start();
        await cubit.toggleSpeaker();
      },
      verify: (cubit) => expect(engine.speaker, isTrue),
      expect: () => [
        const CallState(phase: CallPhase.ringing),
        const CallState(phase: CallPhase.ringing, speaker: true),
      ],
    );
  });
}

class _ThrowingEngine extends FakeCallEngine {
  @override
  Future<void> offer() => throw StateError('no link');
}
