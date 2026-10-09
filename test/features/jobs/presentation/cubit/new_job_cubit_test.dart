import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/cubit/new_job_cubit.dart';
import 'package:salahly/features/jobs/presentation/widgets/schedule_picker.dart';

import '../../../../helpers/error_observer.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockJobsRepository jobs;
  late MockCustomersRepository customers;
  late MockSpeechInput speech;
  late StreamController<List<CustomerSummary>> customerList;
  late StreamController<CustomerRecord?> preselected;
  late void Function(String words) onWords;
  final now = DateTime(2026, 10, 2, 11);

  final sherif = Customer(
    id: 'sherif',
    name: 'م. شريف عادل',
    phone: PhoneNumber.tryParse('01002345678'),
    createdAt: DateTime(2026, 9),
  );
  final noPhone = Customer(
    id: 'no-phone',
    name: 'مدام سهير عبد الله',
    createdAt: DateTime(2026, 9),
  );

  setUpAll(() {
    registerFallbackValue(const JobDraft(customerId: 'x'));
  });

  setUp(() {
    jobs = MockJobsRepository();
    customers = MockCustomersRepository();
    speech = MockSpeechInput();
    customerList = StreamController.broadcast();
    preselected = StreamController.broadcast();
    when(
      () => customers.watchCustomers(today: any(named: 'today')),
    ).thenAnswer((_) => customerList.stream);
    when(
      () => customers.watchCustomer(any()),
    ).thenAnswer((_) => preselected.stream);
    when(() => speech.listen(onWords: any(named: 'onWords'))).thenAnswer((
      invocation,
    ) async {
      onWords =
          invocation.namedArguments[#onWords] as void Function(String words);
      return true;
    });
    when(() => speech.stop()).thenAnswer((_) async {});
    when(
      () => jobs.createJob(any()),
    ).thenAnswer((_) async => const Ok('job-9'));
  });

  NewJobCubit build({String? customerId, DateTime? scheduledAt}) => NewJobCubit(
    jobs: jobs,
    customers: customers,
    speech: speech,
    customerId: customerId,
    scheduledAt: scheduledAt,
    clock: () => now,
  )..start();

  CustomerSummary summaryOf(Customer customer) => CustomerSummary(
    customer: customer,
    jobCount: 1,
    unitCount: 0,
    owedPiastres: 0,
  );

  final oneOClock = ScheduleChoice(
    day: DateTime(2026, 10, 2),
    time: const TimeOfDay(hour: 13, minute: 0),
  );

  group('start', () {
    test('loads the customers to pick from', () async {
      final cubit = build();
      expect(cubit.state.customers, isNull);
      expect(cubit.state.today, DateTime(2026, 10, 2));
      verify(
        () => customers.watchCustomers(today: DateTime(2026, 10, 2)),
      ).called(1);

      customerList.add([summaryOf(sherif), summaryOf(noPhone)]);
      await pumpEventQueue();

      expect(cubit.state.customers, [sherif, noPhone]);
      expect(cubit.state.customer, isNull);
      verifyNever(() => customers.watchCustomer(any()));
      await cubit.close();
    });

    test('starts with the customer it was opened for', () async {
      final cubit = build(customerId: 'sherif');

      preselected.add(CustomerRecord(customer: sherif, units: const []));
      await pumpEventQueue();

      expect(cubit.state.customer, sherif);
      verify(() => customers.watchCustomer('sherif')).called(1);
      await cubit.close();
    });

    test('starts with no customer when that one is gone', () async {
      final cubit = build(customerId: 'gone');

      preselected.add(null);
      await pumpEventQueue();

      expect(cubit.state.customer, isNull);
      await cubit.close();
    });

    test('starts with the visit it was opened for', () async {
      final cubit = build(scheduledAt: DateTime(2026, 10, 5, 15));

      expect(cubit.state.schedule.scheduledAt, DateTime(2026, 10, 5, 15));
      await cubit.close();
    });

    test('reports stream errors', () async {
      final observer = ErrorObserver.install();
      final cubit = build();

      customerList.addError(StateError('boom'));
      await pumpEventQueue();

      expect(observer.errors.single, isA<StateError>());
      await cubit.close();
    });
  });

  test('picks a customer', () async {
    final cubit = build()..selectCustomer(noPhone);

    expect(cubit.state.customer, noPhone);
    await cubit.close();
  });

  test('picks and unpicks problems', () async {
    final cubit = build()
      ..toggleTag(JobTag.freon)
      ..toggleTag(JobTag.cleaning);
    expect(cubit.state.tags, [JobTag.freon, JobTag.cleaning]);

    cubit.toggleTag(JobTag.freon);

    expect(cubit.state.tags, [JobTag.cleaning]);
    await cubit.close();
  });

  group('dictation', () {
    test('adds what is said after what is written', () async {
      final cubit = build()..editDescription('العميل جايب الوحدة ');

      expect(await cubit.toggleListening(), isTrue);
      expect(cubit.state.isListening, isTrue);

      onWords('التكييف');
      onWords('التكييف بيفصل لوحده');

      expect(cubit.state.description, 'العميل جايب الوحدة التكييف بيفصل لوحده');

      expect(await cubit.toggleListening(), isTrue);
      expect(cubit.state.isListening, isFalse);
      verify(() => speech.stop()).called(1);

      onWords('كلام بعد ما وقف');
      expect(cubit.state.description, 'العميل جايب الوحدة التكييف بيفصل لوحده');
      await cubit.close();
    });

    test('says so when the phone cannot take dictation', () async {
      when(
        () => speech.listen(onWords: any(named: 'onWords')),
      ).thenAnswer((_) async => false);
      final cubit = build();

      expect(await cubit.toggleListening(), isFalse);

      expect(cubit.state.isListening, isFalse);
      await cubit.close();
    });

    test('stops when the technician types', () async {
      final cubit = build();
      await cubit.toggleListening();

      cubit.editDescription('مكتوب باليد');

      expect(cubit.state.isListening, isFalse);
      expect(cubit.state.description, 'مكتوب باليد');
      verify(() => speech.stop()).called(1);
      await cubit.close();
    });

    test('keeps within the longest description', () async {
      final cubit = build()
        ..editDescription('ا' * (Job.maxDescriptionLength - 2));
      await cubit.toggleListening();

      onWords('كلام كتير');

      expect(cubit.state.description, hasLength(Job.maxDescriptionLength));
      await cubit.close();
    });

    test('stops when the form closes', () async {
      final cubit = build();
      await cubit.toggleListening();

      await cubit.close();

      verify(() => speech.stop()).called(1);
    });
  });

  group('confirmation', () {
    test('is offered with a phone and a date, and on by default', () async {
      final cubit = build();
      expect(cubit.state.canSendConfirmation, isFalse);

      cubit.selectCustomer(sherif);
      expect(cubit.state.canSendConfirmation, isFalse);

      cubit.changeSchedule(oneOClock);
      expect(cubit.state.canSendConfirmation, isTrue);
      expect(cubit.state.sendsConfirmation, isTrue);

      cubit.setSendConfirmation(send: false);
      expect(cubit.state.sendsConfirmation, isFalse);
      await cubit.close();
    });

    test('is not offered for a customer with no phone', () async {
      final cubit = build()
        ..selectCustomer(noPhone)
        ..changeSchedule(oneOClock);

      expect(cubit.state.canSendConfirmation, isFalse);
      expect(cubit.state.sendsConfirmation, isFalse);
      await cubit.close();
    });
  });

  group('save', () {
    test('asks for the customer first', () async {
      final cubit = build();

      await cubit.save();

      expect(cubit.state.showsErrors, isTrue);
      expect(cubit.state.status, NewJobStatus.editing);
      verifyNever(() => jobs.createJob(any()));
      await cubit.close();
    });

    test('asks for the time when only a day is picked', () async {
      final cubit = build()
        ..selectCustomer(sherif)
        ..changeSchedule(ScheduleChoice(day: DateTime(2026, 10, 3)));

      await cubit.save();

      expect(cubit.state.showsErrors, isTrue);
      verifyNever(() => jobs.createJob(any()));
      await cubit.close();
    });

    test('saves the job and holds it for what comes next', () async {
      final cubit = build()
        ..selectCustomer(sherif)
        ..toggleTag(JobTag.freon)
        ..toggleTag(JobTag.cleaning)
        ..editDescription('العميل جايب الوحدة')
        ..changeSchedule(oneOClock);
      final states = <NewJobState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.save();
      await pumpEventQueue();

      expect(states.map((state) => state.status), [
        NewJobStatus.saving,
        NewJobStatus.saved,
      ]);
      verify(
        () => jobs.createJob(
          JobDraft(
            customerId: 'sherif',
            tags: const [JobTag.cleaning, JobTag.freon],
            description: 'العميل جايب الوحدة',
            scheduledAt: DateTime(2026, 10, 2, 13),
          ),
        ),
      ).called(1);
      final saved = cubit.state.saved!;
      expect(saved.id, 'job-9');
      expect(saved.customerId, 'sherif');
      expect(saved.tags, [JobTag.cleaning, JobTag.freon]);
      expect(saved.scheduledAt, DateTime(2026, 10, 2, 13));
      await subscription.cancel();
      await cubit.close();
    });

    test('saves a job with no date yet', () async {
      final cubit = build()..selectCustomer(noPhone);

      await cubit.save();

      expect(cubit.state.status, NewJobStatus.saved);
      final draft =
          verify(() => jobs.createJob(captureAny())).captured.single
              as JobDraft;
      expect(draft.scheduledAt, isNull);
      expect(draft.tags, isEmpty);
      await cubit.close();
    });

    test('stops dictation before saving', () async {
      final cubit = build()..selectCustomer(sherif);
      await cubit.toggleListening();

      await cubit.save();

      expect(cubit.state.isListening, isFalse);
      verify(() => speech.stop()).called(1);
      await cubit.close();
    });

    test('saves once even when tapped twice', () async {
      final result = Completer<Result<String>>();
      when(() => jobs.createJob(any())).thenAnswer((_) => result.future);
      final cubit = build()..selectCustomer(sherif);

      final first = cubit.save();
      await cubit.save();
      result.complete(const Ok('job-9'));
      await first;
      await cubit.save();

      verify(() => jobs.createJob(any())).called(1);
      await cubit.close();
    });

    test('says why saving failed and lets the technician retry', () async {
      when(
        () => jobs.createJob(any()),
      ).thenAnswer((_) async => const Err(UnexpectedFailure()));
      final cubit = build()..selectCustomer(sherif);

      await cubit.save();

      expect(cubit.state.status, NewJobStatus.failed);
      expect(cubit.state.failure, const UnexpectedFailure());

      when(
        () => jobs.createJob(any()),
      ).thenAnswer((_) async => const Ok('job-9'));
      await cubit.save();

      expect(cubit.state.status, NewJobStatus.saved);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });
  });
}
