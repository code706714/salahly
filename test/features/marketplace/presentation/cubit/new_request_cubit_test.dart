import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/request_draft.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/new_request_cubit.dart';

import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockConsumerRequestsRepository requests;
  late MockSpeechInput speech;
  late DateTime now;

  final today = DateTime(2026, 10, 6);
  final tomorrow = DateTime(2026, 10, 7);

  setUpAll(registerConsumerScreenFallbacks);

  setUp(() {
    requests = MockConsumerRequestsRepository();
    speech = MockSpeechInput();
    now = DateTime(2026, 10, 6, 10);
    when(
      requests.fetchAddresses,
    ).thenAnswer((_) async => const Ok([testHome, testMomsHome]));
    when(() => speech.stop()).thenAnswer((_) async {});
  });

  NewRequestCubit build({String? categoryId, String? technicianId}) =>
      NewRequestCubit(
        requests: requests,
        speech: speech,
        categoryId: categoryId,
        technicianId: technicianId,
        clock: () => now,
      )..useCategories(TestCategories.all);

  /// A cubit with every step filled in, on the time step.
  Future<NewRequestCubit> filled({
    List<String> photos = const [],
    String? technicianId,
  }) async {
    final cubit = build(technicianId: technicianId);
    await cubit.start();
    cubit
      ..selectIssue(RequestIssue.notCooling)
      ..editDescription('  الهوا مش ساقع  ');
    photos.forEach(cubit.addPhoto);
    await cubit.next();
    await cubit.next();
    cubit
      ..selectDay(tomorrow)
      ..selectWindow(RequestWindow.noon);
    return cubit;
  }

  group('category', () {
    test('starts on the category asked for while it is open', () async {
      final cubit = build(categoryId: 'ac');

      expect(cubit.state.category, TestCategories.airConditioning);
      await cubit.close();
    });

    test('falls back to the first open category', () async {
      for (final id in ['plumbing', 'unknown', null]) {
        final cubit = build(categoryId: id);
        expect(cubit.state.category, TestCategories.airConditioning);
        await cubit.close();
      }
    });

    test('waits for the catalog', () async {
      final cubit = NewRequestCubit(requests: requests, speech: speech)
        ..useCategories(const []);

      expect(cubit.state.category, isNull);
      expect(cubit.state.problemDone, isFalse);
      await cubit.close();
    });
  });

  group('start', () {
    test('fetches the addresses and picks the first', () async {
      final cubit = build();
      await cubit.start();

      expect(cubit.state.addresses, [testHome, testMomsHome]);
      expect(cubit.state.address, testHome);
      verifyNever(() => requests.fetchTechnician(any()));
      await cubit.close();
    });

    test('names the technician asked first', () async {
      when(
        () => requests.fetchTechnician('tech-1'),
      ).thenAnswer((_) async => Ok(testTechnicianProfile()));
      final cubit = build(technicianId: 'tech-1');
      await cubit.start();

      expect(cubit.state.technician, testTechnicianCard());
      await cubit.close();
    });

    test(
      'goes on without the technician when they cannot be fetched',
      () async {
        when(
          () => requests.fetchTechnician('tech-1'),
        ).thenAnswer((_) async => const Err(NetworkFailure()));
        final cubit = build(technicianId: 'tech-1');
        await cubit.start();

        expect(cubit.state.technician, isNull);
        expect(cubit.state.addresses, isNotEmpty);
        await cubit.close();
      },
    );

    test('marks addresses that could not be fetched, and retries', () async {
      when(
        requests.fetchAddresses,
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final cubit = build();
      await cubit.loadAddresses();
      expect(cubit.state.addressesFailed, isTrue);
      expect(cubit.state.addresses, isNull);

      when(requests.fetchAddresses).thenAnswer((_) async => const Ok([]));
      await cubit.loadAddresses();

      expect(cubit.state.addressesFailed, isFalse);
      expect(cubit.state.addresses, isEmpty);
      expect(cubit.state.addressId, isNull);
      await cubit.close();
    });

    test('keeps the picked address when fetching again', () async {
      final cubit = build();
      await cubit.loadAddresses();
      cubit.selectAddress('address-2');
      await cubit.loadAddresses();

      expect(cubit.state.address, testMomsHome);
      await cubit.close();
    });
  });

  group('the problem', () {
    test('needs an issue', () async {
      final cubit = build();
      await cubit.next();

      expect(cubit.state.step, NewRequestStep.problem);
      expect(cubit.state.showsErrors, isTrue);

      cubit.selectIssue(RequestIssue.leaking);
      await cubit.next();

      expect(cubit.state.step, NewRequestStep.address);
      expect(cubit.state.showsErrors, isFalse);
      await cubit.close();
    });

    test('needs a description when the issue is something else', () async {
      final cubit = build()
        ..selectIssue(RequestIssue.other)
        ..editDescription('   ');
      await cubit.next();
      expect(cubit.state.step, NewRequestStep.problem);
      expect(cubit.state.needsDescription, isTrue);

      cubit.editDescription('الريموت بايظ');
      await cubit.next();
      expect(cubit.state.step, NewRequestStep.address);
      await cubit.close();
    });

    test('takes up to four photos and removes one', () async {
      final cubit = build();
      for (var i = 1; i <= 5; i++) {
        cubit.addPhoto('/photos/$i.jpg');
      }
      expect(cubit.state.photos, [
        '/photos/1.jpg',
        '/photos/2.jpg',
        '/photos/3.jpg',
        '/photos/4.jpg',
      ]);

      cubit.removePhoto('/photos/2.jpg');
      expect(cubit.state.photos, [
        '/photos/1.jpg',
        '/photos/3.jpg',
        '/photos/4.jpg',
      ]);
      await cubit.close();
    });
  });

  group('dictation', () {
    late void Function(String words) onWords;

    setUp(() {
      when(
        () => speech.listen(onWords: any(named: 'onWords')),
      ).thenAnswer((invocation) async {
        onWords =
            invocation.namedArguments[#onWords] as void Function(String words);
        return true;
      });
    });

    test('adds what is said after what is written', () async {
      final cubit = build()..editDescription('التكييف');
      expect(await cubit.toggleListening(), isTrue);
      expect(cubit.state.isListening, isTrue);

      onWords('مش بيبرّد');
      expect(cubit.state.description, 'التكييف مش بيبرّد');
      onWords('مش بيبرّد خالص');
      expect(cubit.state.description, 'التكييف مش بيبرّد خالص');

      await cubit.toggleListening();
      expect(cubit.state.isListening, isFalse);
      verify(() => speech.stop()).called(1);

      onWords('كلام بعد ما وقفت');
      expect(cubit.state.description, 'التكييف مش بيبرّد خالص');
      await cubit.close();
    });

    test('keeps within the longest description', () async {
      final cubit = build()..editDescription('ا' * 995);
      await cubit.toggleListening();
      onWords('كلام كتير');

      expect(
        cubit.state.description.length,
        NewRequestCubit.maxDescriptionLength,
      );
      await cubit.close();
    });

    test('typing stops it', () async {
      final cubit = build();
      await cubit.toggleListening();
      cubit.editDescription('بكتب');
      await pumpEventQueue();

      expect(cubit.state.isListening, isFalse);
      expect(cubit.state.description, 'بكتب');
      verify(() => speech.stop()).called(1);
      await cubit.close();
    });

    test('says when the phone cannot take it', () async {
      when(
        () => speech.listen(onWords: any(named: 'onWords')),
      ).thenAnswer((_) async => false);
      final cubit = build();

      expect(await cubit.toggleListening(), isFalse);
      expect(cubit.state.isListening, isFalse);
      await cubit.close();
    });

    test('stops when moving on and when closing', () async {
      final cubit = build()..selectIssue(RequestIssue.noisy);
      await cubit.toggleListening();
      await cubit.next();
      expect(cubit.state.isListening, isFalse);
      verify(() => speech.stop()).called(1);

      cubit.back();
      await cubit.toggleListening();
      await cubit.close();
      verify(() => speech.stop()).called(1);
    });
  });

  group('the address', () {
    test('needs one picked', () async {
      when(requests.fetchAddresses).thenAnswer((_) async => const Ok([]));
      final cubit = build()..selectIssue(RequestIssue.noisy);
      await cubit.loadAddresses();
      await cubit.next();
      await cubit.next();

      expect(cubit.state.step, NewRequestStep.address);
      expect(cubit.state.showsErrors, isTrue);
      await cubit.close();
    });

    test('a new one is saved and picked', () async {
      const draft = ConsumerAddressDraft(
        label: 'الشغل',
        areaId: 'heliopolis',
        details: 'شارع الميرغني',
      );
      when(
        () => requests.saveAddress(draft),
      ).thenAnswer((_) async => const Ok('address-3'));
      final cubit = build();
      await cubit.loadAddresses();

      expect(await cubit.addAddress(draft), isNull);

      const saved = ConsumerAddress(
        id: 'address-3',
        label: 'الشغل',
        areaId: 'heliopolis',
        details: 'شارع الميرغني',
      );
      expect(cubit.state.addresses, [testHome, testMomsHome, saved]);
      expect(cubit.state.address, saved);
      await cubit.close();
    });

    test('says why a new one was not saved', () async {
      when(
        () => requests.saveAddress(any()),
      ).thenAnswer((_) async => const Err(AddressLimitFailure()));
      final cubit = build();
      await cubit.loadAddresses();

      expect(
        await cubit.addAddress(
          const ConsumerAddressDraft(
            label: 'ا',
            areaId: 'nasr_city',
            details: 'abc',
          ),
        ),
        const AddressLimitFailure(),
      );
      expect(cubit.state.addresses, [testHome, testMomsHome]);
      await cubit.close();
    });

    test('back goes a step back, and leaves on the first', () async {
      final cubit = build()..selectIssue(RequestIssue.noisy);
      await cubit.loadAddresses();
      await cubit.next();
      await cubit.next();
      expect(cubit.state.step, NewRequestStep.time);

      expect(cubit.back(), isTrue);
      expect(cubit.state.step, NewRequestStep.address);
      expect(cubit.back(), isTrue);
      expect(cubit.state.step, NewRequestStep.problem);
      expect(cubit.back(), isFalse);
      await cubit.close();
    });
  });

  group('the time', () {
    test('offers today, tomorrow and the day after', () async {
      final cubit = build();

      expect(cubit.state.days, [today, tomorrow, DateTime(2026, 10, 8)]);
      await cubit.close();
    });

    test('closes a window an hour before it ends', () async {
      now = DateTime(2026, 10, 6, 11, 30);
      final cubit = build()..selectDay(today);

      expect(cubit.state.isOpen(today, RequestWindow.morning), isFalse);
      expect(cubit.state.isOpen(today, RequestWindow.noon), isTrue);

      cubit.selectWindow(RequestWindow.morning);
      expect(cubit.state.window, isNull);
      cubit.selectWindow(RequestWindow.noon);
      expect(cubit.state.window, RequestWindow.noon);
      await cubit.close();
    });

    test('a day with every window over cannot be picked', () async {
      now = DateTime(2026, 10, 6, 20, 30);
      final cubit = build()..selectDay(today);

      expect(cubit.state.hasOpenWindow(today), isFalse);
      expect(cubit.state.day, isNull);

      cubit.selectDay(tomorrow);
      expect(cubit.state.day, tomorrow);
      await cubit.close();
    });

    test('a day not offered cannot be picked', () async {
      final cubit = build()..selectDay(DateTime(2026, 10, 12));

      expect(cubit.state.day, isNull);
      await cubit.close();
    });

    test('a window can be picked before the day', () async {
      final cubit = build()..selectWindow(RequestWindow.morning);
      expect(cubit.state.window, RequestWindow.morning);
      expect(cubit.state.timeDone, isFalse);

      cubit.selectDay(tomorrow);
      expect(cubit.state.window, RequestWindow.morning);
      expect(cubit.state.timeDone, isTrue);
      await cubit.close();
    });

    test('changing the day drops a window that is over on it', () async {
      now = DateTime(2026, 10, 6, 11, 30);
      final cubit = build()
        ..selectDay(tomorrow)
        ..selectWindow(RequestWindow.morning)
        ..selectDay(today);

      expect(cubit.state.day, today);
      expect(cubit.state.window, isNull);

      cubit
        ..selectWindow(RequestWindow.evening)
        ..selectDay(tomorrow);
      expect(cubit.state.window, RequestWindow.evening);
      await cubit.close();
    });

    test('drops a pick that ran out while the form was open', () async {
      final cubit = build()
        ..selectDay(today)
        ..selectWindow(RequestWindow.morning);
      expect(cubit.state.timeDone, isTrue);

      now = DateTime(2026, 10, 6, 11, 30);
      cubit.selectWindow(RequestWindow.noon);
      expect(cubit.state.window, RequestWindow.noon);
      expect(cubit.state.now, now);
      await cubit.close();
    });
  });

  group('send', () {
    test('sends the request with the photos uploaded', () async {
      when(
        () => requests.uploadPhoto(any()),
      ).thenAnswer((invocation) async {
        final path = invocation.positionalArguments.first as String;
        return Ok('consumer-1/${path.split('/').last}');
      });
      when(() => requests.sendRequest(any())).thenAnswer(
        (_) async => const Ok(SentRequest(id: 'request-9', sentTo: 5)),
      );
      final cubit = await filled(photos: ['/p/1.jpg', '/p/2.jpg']);
      final statuses = <(NewRequestStatus, int)>[];
      final sub = cubit.stream.listen(
        (state) => statuses.add((state.status, state.uploaded)),
      );

      await cubit.next();
      await pumpEventQueue();
      await sub.cancel();

      expect(statuses, [
        (NewRequestStatus.uploading, 0),
        (NewRequestStatus.uploading, 1),
        (NewRequestStatus.uploading, 2),
        (NewRequestStatus.sending, 2),
        (NewRequestStatus.sent, 2),
      ]);
      expect(cubit.state.sent, const SentRequest(id: 'request-9', sentTo: 5));
      verify(
        () => requests.sendRequest(
          RequestDraft(
            categoryId: 'ac',
            issue: RequestIssue.notCooling,
            description: 'الهوا مش ساقع',
            photoPaths: const ['consumer-1/1.jpg', 'consumer-1/2.jpg'],
            addressId: 'address-1',
            day: tomorrow,
            window: RequestWindow.noon,
          ),
        ),
      ).called(1);

      await cubit.send();
      verifyNever(() => requests.sendRequest(any()));
      await cubit.close();
    });

    test('sends no description when none was written, and asks the '
        'technician first', () async {
      when(() => requests.sendRequest(any())).thenAnswer(
        (_) async => const Ok(SentRequest(id: 'request-9', sentTo: 1)),
      );
      when(
        () => requests.fetchTechnician('tech-1'),
      ).thenAnswer((_) async => Ok(testTechnicianProfile()));
      final cubit = await filled(technicianId: 'tech-1');
      cubit.editDescription('');

      await cubit.send();

      final draft =
          verify(() => requests.sendRequest(captureAny())).captured.single
              as RequestDraft;
      expect(draft.description, isNull);
      expect(draft.technicianId, 'tech-1');
      expect(draft.photoPaths, isEmpty);
      await cubit.close();
    });

    test('asks no one first when the form could not name them', () async {
      when(
        () => requests.fetchTechnician('tech-1'),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      when(() => requests.sendRequest(any())).thenAnswer(
        (_) async => const Ok(SentRequest(id: 'request-9', sentTo: 3)),
      );
      final cubit = await filled(technicianId: 'tech-1');

      await cubit.send();

      final draft =
          verify(() => requests.sendRequest(captureAny())).captured.single
              as RequestDraft;
      expect(draft.technicianId, isNull);
      await cubit.close();
    });

    test('says why sending failed, and tries again', () async {
      when(
        () => requests.sendRequest(any()),
      ).thenAnswer((_) async => const Err(NoCreditsFailure()));
      final cubit = await filled();

      await cubit.next();

      expect(cubit.state.status, NewRequestStatus.failed);
      expect(cubit.state.failure, const NoCreditsFailure());
      expect(cubit.state.isSending, isFalse);

      when(() => requests.sendRequest(any())).thenAnswer(
        (_) async => const Ok(SentRequest(id: 'request-9', sentTo: 0)),
      );
      await cubit.next();

      expect(cubit.state.status, NewRequestStatus.sent);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });

    test('a failed upload stops the send, and uploaded photos are not '
        'uploaded again', () async {
      when(
        () => requests.uploadPhoto('/p/1.jpg'),
      ).thenAnswer((_) async => const Ok('consumer-1/1.jpg'));
      when(
        () => requests.uploadPhoto('/p/2.jpg'),
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final cubit = await filled(photos: ['/p/1.jpg', '/p/2.jpg']);

      await cubit.send();

      expect(cubit.state.status, NewRequestStatus.failed);
      expect(cubit.state.failure, const NetworkFailure());
      verifyNever(() => requests.sendRequest(any()));

      when(
        () => requests.uploadPhoto('/p/2.jpg'),
      ).thenAnswer((_) async => const Ok('consumer-1/2.jpg'));
      when(() => requests.sendRequest(any())).thenAnswer(
        (_) async => const Ok(SentRequest(id: 'request-9', sentTo: 2)),
      );
      await cubit.send();

      verify(() => requests.uploadPhoto('/p/1.jpg')).called(1);
      verify(() => requests.uploadPhoto('/p/2.jpg')).called(2);
      expect(cubit.state.status, NewRequestStatus.sent);
      await cubit.close();
    });

    test('needs the day and time', () async {
      final cubit = build()..selectIssue(RequestIssue.noisy);
      await cubit.loadAddresses();
      await cubit.next();
      await cubit.next();

      await cubit.next();

      expect(cubit.state.showsErrors, isTrue);
      expect(cubit.state.status, NewRequestStatus.editing);
      verifyNever(() => requests.sendRequest(any()));
      await cubit.close();
    });

    test('does not send a window that ran out', () async {
      final cubit = await filled();
      cubit
        ..selectDay(today)
        ..selectWindow(RequestWindow.morning);
      now = DateTime(2026, 10, 6, 11, 30);

      await cubit.send();

      expect(cubit.state.window, isNull);
      expect(cubit.state.showsErrors, isTrue);
      verifyNever(() => requests.sendRequest(any()));
      await cubit.close();
    });

    test('sends once while sending', () async {
      final sent = Completer<Result<SentRequest>>();
      when(() => requests.sendRequest(any())).thenAnswer((_) => sent.future);
      final cubit = await filled();

      final first = cubit.send();
      await cubit.send();
      expect(cubit.back(), isFalse);
      sent.complete(const Ok(SentRequest(id: 'request-9', sentTo: 3)));
      await first;

      verify(() => requests.sendRequest(any())).called(1);
      await cubit.close();
    });

    test('ignores an answer arriving after closing', () async {
      final sent = Completer<Result<SentRequest>>();
      when(() => requests.sendRequest(any())).thenAnswer((_) => sent.future);
      final cubit = await filled();

      final sending = cubit.send();
      await cubit.close();
      sent.complete(const Ok(SentRequest(id: 'request-9', sentTo: 3)));
      await sending;

      expect(cubit.state.status, NewRequestStatus.sending);
    });
  });
}
