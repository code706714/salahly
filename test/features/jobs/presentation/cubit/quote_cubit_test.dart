import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/presentation/cubit/quote_cubit.dart';

import '../../../../helpers/error_observer.dart';
import '../../../../helpers/job_details_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockJobsRepository jobs;
  late StreamController<JobDetails?> details;
  const failure = UnexpectedFailure('disk full');
  const suggestions = [
    ItemSuggestion(title: 'تنظيف', unitPricePiastres: 25000),
  ];

  setUpAll(() {
    registerFallbackValue(<JobItemDraft>[]);
    registerFallbackValue(QuoteStatus.none);
  });

  setUp(() {
    jobs = MockJobsRepository();
    details = StreamController.broadcast();
    when(() => jobs.watchJob('job-1')).thenAnswer((_) => details.stream);
    when(jobs.itemSuggestions).thenAnswer((_) async => suggestions);
    when(
      () => jobs.saveQuote(
        any(),
        items: any(named: 'items'),
        validDays: any(named: 'validDays'),
        status: any(named: 'status'),
      ),
    ).thenAnswer((_) async => const Ok(null));
  });

  tearDown(() => details.close());

  Future<QuoteCubit> started(JobDetails? first) async {
    final cubit = QuoteCubit(jobs: jobs, jobId: 'job-1');
    unawaited(cubit.start());
    details.add(first);
    await pumpEventQueue();
    return cubit;
  }

  JobItemDraft draft(JobItem item) => JobItemDraft(
    id: item.id,
    title: item.title,
    unitPricePiastres: item.unitPricePiastres,
    quantity: item.quantity,
  );

  List<JobItemDraft> savedItems() =>
      verify(
            () => jobs.saveQuote(
              'job-1',
              items: captureAny(named: 'items'),
              validDays: any(named: 'validDays'),
              status: any(named: 'status'),
            ),
          ).captured.single
          as List<JobItemDraft>;

  group('loading', () {
    test('works without earlier lines when they fail to load', () async {
      final observer = ErrorObserver.install();
      when(jobs.itemSuggestions).thenThrow(StateError('disk'));

      final cubit = await started(testDetails(items: sampleItems));

      expect(cubit.state.status, JobDetailsStatus.ready);
      expect(cubit.state.suggestions, isEmpty);
      expect(observer.errors.single, isA<StateError>());
      await cubit.close();
    });

    test('shows the saved lines, validity and earlier lines', () async {
      final cubit = await started(
        testDetails(
          job: testJob(quoteStatus: QuoteStatus.draft),
          items: sampleItems,
        ),
      );
      expect(cubit.state.status, JobDetailsStatus.ready);
      expect(cubit.state.items, sampleItems.map(draft).toList());
      expect(cubit.state.validDays, Job.defaultQuoteValidDays);
      expect(cubit.state.suggestions, suggestions);
      expect(cubit.state.totalPiastres, 145000);
      expect(cubit.state.isDirty, isFalse);
      await cubit.close();
    });

    test('a job never found is missing', () async {
      final cubit = await started(null);
      expect(cubit.state.status, JobDetailsStatus.missing);
      await cubit.close();
    });

    test('a job deleted while open is deleted', () async {
      final cubit = await started(testDetails());
      details.add(null);
      await pumpEventQueue();
      expect(cubit.state.status, JobDetailsStatus.deleted);
      await cubit.close();
    });

    test('keeps unsaved edits when the job changes underneath', () async {
      final cubit = await started(testDetails(items: sampleItems));
      cubit.remove(0);
      details.add(testDetails(items: [sampleItems.first]));
      await pumpEventQueue();
      expect(cubit.state.items, sampleItems.skip(1).map(draft).toList());
      await cubit.close();
    });
  });

  group('editing', () {
    test('steps how many of a line, never below one', () async {
      final cubit = await started(testDetails(items: sampleItems));

      cubit.increment(1);
      expect(cubit.state.items[1].quantity, 5);
      expect(cubit.state.isDirty, isTrue);
      cubit
        ..decrement(1)
        ..decrement(0);
      expect(cubit.state.items[1].quantity, 4);
      expect(cubit.state.items[0].quantity, 1);
      await cubit.close();
    });

    test('stops at the most a line can have', () async {
      final cubit = await started(
        testDetails(
          items: [testItem('ماسورة', 100, quantity: JobItem.maxQuantity)],
        ),
      );
      cubit.increment(0);
      expect(cubit.state.items.single.quantity, JobItem.maxQuantity);
      expect(cubit.state.isDirty, isFalse);
      await cubit.close();
    });

    test('adds a new line, or one more of the same line', () async {
      final cubit = await started(testDetails(items: sampleItems));

      cubit.addItem(
        const JobItemDraft(title: 'تنظيف', unitPricePiastres: 25000),
      );
      expect(cubit.state.items, hasLength(4));
      expect(cubit.state.items.last.title, 'تنظيف');

      cubit.addItem(
        const JobItemDraft(
          title: 'حامل للوحدة الخارجية',
          unitPricePiastres: 15000,
        ),
      );
      expect(cubit.state.items, hasLength(4));
      expect(cubit.state.items[2].quantity, 2);
      await cubit.close();
    });

    test('removes a line', () async {
      final cubit = await started(testDetails(items: sampleItems));
      cubit.remove(1);
      expect(cubit.state.items.map((item) => item.title), [
        sampleItems[0].title,
        sampleItems[2].title,
      ]);
      expect(cubit.state.totalPiastres, 105000);
      await cubit.close();
    });

    test('changes how long the quote holds', () async {
      final cubit = await started(testDetails(items: sampleItems));
      cubit.setValidDays(3);
      expect(cubit.state.isDirty, isFalse);
      cubit.setValidDays(7);
      expect(cubit.state.validDays, 7);
      expect(cubit.state.isDirty, isTrue);
      await cubit.close();
    });
  });

  group('saving', () {
    test('a draft keeps the lines with their ids', () async {
      final cubit = await started(testDetails(items: sampleItems));
      cubit
        ..increment(1)
        ..setValidDays(7);

      expect(await cubit.saveDraft(), isTrue);

      final items =
          verify(
                () => jobs.saveQuote(
                  'job-1',
                  items: captureAny(named: 'items'),
                  validDays: 7,
                  status: QuoteStatus.draft,
                ),
              ).captured.single
              as List<JobItemDraft>;
      expect(items.map((item) => item.id), sampleItems.map((item) => item.id));
      expect(items[1].quantity, 5);
      expect(cubit.state.isDirty, isFalse);
      expect(cubit.state.isSaving, isFalse);
      await cubit.close();
    });

    test('a quote already sent stays sent when saved', () async {
      final cubit = await started(
        testDetails(
          job: testJob(quoteStatus: QuoteStatus.sent),
          items: sampleItems,
        ),
      );
      await cubit.saveDraft();
      verify(
        () => jobs.saveQuote(
          'job-1',
          items: any(named: 'items'),
          validDays: 3,
          status: QuoteStatus.sent,
        ),
      ).called(1);
      await cubit.close();
    });

    test('a quote without lines is saved as no quote', () async {
      final cubit = await started(
        testDetails(job: testJob(quoteStatus: QuoteStatus.draft)),
      );
      await cubit.saveDraft();
      verify(
        () => jobs.saveQuote(
          'job-1',
          items: const [],
          validDays: 3,
          status: QuoteStatus.none,
        ),
      ).called(1);
      await cubit.close();
    });

    test('sends a quote with lines, never an empty one', () async {
      final empty = await started(testDetails());
      expect(await empty.send(), isFalse);
      expect(await empty.markAccepted(), isFalse);
      verifyNever(
        () => jobs.saveQuote(
          any(),
          items: any(named: 'items'),
          validDays: any(named: 'validDays'),
          status: any(named: 'status'),
        ),
      );
      await empty.close();

      final cubit = await started(testDetails(items: sampleItems));
      expect(await cubit.send(), isTrue);
      verify(
        () => jobs.saveQuote(
          'job-1',
          items: any(named: 'items'),
          validDays: 3,
          status: QuoteStatus.sent,
        ),
      ).called(1);
      await cubit.close();
    });

    test('records that the customer accepted', () async {
      final cubit = await started(
        testDetails(
          job: testJob(quoteStatus: QuoteStatus.sent),
          items: sampleItems,
        ),
      );
      expect(await cubit.markAccepted(), isTrue);
      expect(savedItems(), sampleItems.map(draft).toList());
      await cubit.close();
    });

    test('never records a yes for a platform job', () async {
      final cubit = await started(
        testDetails(
          job: testJob(
            quoteStatus: QuoteStatus.sent,
            source: JobSource.platform,
          ),
          items: sampleItems,
        ),
      );
      expect(await cubit.markAccepted(), isFalse);
      verifyNever(
        () => jobs.saveQuote(
          any(),
          items: any(named: 'items'),
          validDays: any(named: 'validDays'),
          status: any(named: 'status'),
        ),
      );
      await cubit.close();
    });

    test("keeps a platform job's accepted price until it changes", () async {
      final platform = testDetails(
        job: testJob(
          quoteStatus: QuoteStatus.accepted,
          source: JobSource.platform,
        ),
        items: sampleItems,
      );
      final unchanged = await started(platform);
      await unchanged.saveDraft();
      verify(
        () => jobs.saveQuote(
          'job-1',
          items: any(named: 'items'),
          validDays: 3,
          status: QuoteStatus.accepted,
        ),
      ).called(1);
      await unchanged.close();

      final changed = await started(platform);
      changed.addItem(
        const JobItemDraft(title: 'شحن فريون', unitPricePiastres: 30000),
      );
      await changed.saveDraft();
      verify(
        () => jobs.saveQuote(
          'job-1',
          items: any(named: 'items'),
          validDays: 3,
          status: QuoteStatus.draft,
        ),
      ).called(1);
      await changed.close();
    });

    test('a declined price change is saved as a draft', () async {
      final cubit = await started(
        testDetails(
          job: testJob(
            quoteStatus: QuoteStatus.declined,
            source: JobSource.platform,
          ),
          items: sampleItems,
        ),
      );
      await cubit.saveDraft();
      verify(
        () => jobs.saveQuote(
          'job-1',
          items: any(named: 'items'),
          validDays: 3,
          status: QuoteStatus.draft,
        ),
      ).called(1);
      await cubit.close();
    });

    test('takes the saved lines from the job once saved', () async {
      final cubit = await started(testDetails());
      cubit.addItem(
        const JobItemDraft(title: 'تنظيف', unitPricePiastres: 25000),
      );
      await cubit.saveDraft();
      expect(cubit.state.items.single.id, isNull);

      details.add(testDetails(items: [testItem('تنظيف', 250, id: 'new')]));
      await pumpEventQueue();

      expect(cubit.state.items.single.id, 'new');
      await cubit.close();
    });

    test('takes the saved lines that arrived while saving', () async {
      final saving = Completer<Result<void>>();
      when(
        () => jobs.saveQuote(
          any(),
          items: any(named: 'items'),
          validDays: any(named: 'validDays'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) => saving.future);
      final cubit = await started(testDetails());
      cubit.addItem(
        const JobItemDraft(title: 'تنظيف', unitPricePiastres: 25000),
      );

      final save = cubit.saveDraft();
      expect(cubit.state.isSaving, isTrue);
      details.add(testDetails(items: [testItem('تنظيف', 250, id: 'new')]));
      await pumpEventQueue();
      expect(cubit.state.items.single.id, isNull);
      saving.complete(const Ok(null));
      await save;

      expect(cubit.state.items.single.id, 'new');
      expect(cubit.state.isDirty, isFalse);
      await cubit.close();
    });

    test('reports a failure and keeps the edits', () async {
      when(
        () => jobs.saveQuote(
          any(),
          items: any(named: 'items'),
          validDays: any(named: 'validDays'),
          status: any(named: 'status'),
        ),
      ).thenAnswer((_) async => const Err(failure));
      final cubit = await started(testDetails(items: sampleItems));
      cubit.remove(0);

      expect(await cubit.saveDraft(), isFalse);

      expect(cubit.state.failure, failure);
      expect(cubit.state.isDirty, isTrue);
      expect(cubit.state.items, hasLength(2));
      await cubit.close();
    });
  });
}
