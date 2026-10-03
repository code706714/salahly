import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/presentation/cubit/new_job_cubit.dart';
import 'package:salahly/features/jobs/presentation/pages/job_page.dart';
import 'package:salahly/features/jobs/presentation/pages/jobs_page.dart';
import 'package:salahly/features/jobs/presentation/pages/new_job_page.dart';
import 'package:salahly/features/jobs/presentation/widgets/schedule_picker.dart';

import '../../../../helpers/job_seed.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

class _MockNewJobCubit extends MockCubit<NewJobState> implements NewJobCubit {}

void main() {
  late _MockNewJobCubit cubit;
  late MockSessionCubit session;
  late MockExternalApps apps;
  final today = DateTime(2026, 10, 2);

  final sherif = Customer(
    id: 'sherif',
    name: 'م. شريف عادل',
    phone: PhoneNumber.tryParse('01002345678'),
    createdAt: DateTime(2026, 9),
  );
  final hala = Customer(
    id: 'hala',
    name: 'أ. هالة فتحي',
    createdAt: DateTime(2026, 9),
  );
  final oneOClock = ScheduleChoice(
    day: today,
    time: const TimeOfDay(hour: 13, minute: 0),
  );

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    TechnicianApp.registerFallbacks();
    registerFallbackValue(ScheduleChoice.none);
    registerFallbackValue(JobTag.cleaning);
    registerFallbackValue(hala);
  });

  setUp(() {
    cubit = _MockNewJobCubit();
    session = MockSessionCubit();
    apps = MockExternalApps();
    when(() => session.state).thenReturn(
      const SessionReady(
        user: AuthUser(id: 'user-1'),
        profile: UserProfile(
          id: 'user-1',
          phone: '+201002345678',
          fullName: 'محمود عبد الله',
          activeRole: UserRole.technician,
          technician: TechnicianProfile(
            verificationStatus: VerificationStatus.approved,
            jobCredits: 3,
          ),
        ),
      ),
    );
    when(
      () => apps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
    when(() => cubit.save()).thenAnswer((_) async {});
    when(() => cubit.toggleListening()).thenAnswer((_) async => true);
  });

  NewJobState form({
    List<Customer>? customers = const [],
    Customer? customer,
    List<JobTag> tags = const [],
    String description = '',
    ScheduleChoice schedule = ScheduleChoice.none,
    bool sendConfirmation = true,
    bool isListening = false,
    bool showsErrors = false,
  }) => NewJobState(
    today: today,
    customers: customers,
    customer: customer,
    tags: tags,
    description: description,
    schedule: schedule,
    sendConfirmation: sendConfirmation,
    isListening: isListening,
    showsErrors: showsErrors,
  );

  void show(NewJobState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpView(WidgetTester tester) => tester.pumpApp(
    const NewJobView(),
    repositories: [RepositoryProvider<ExternalApps>.value(value: apps)],
    blocs: [
      BlocProvider<NewJobCubit>.value(value: cubit),
      BlocProvider<SessionCubit>.value(value: session),
    ],
    stubRoutes: [AppRoutes.newCustomer, AppRoutes.job('job-9')],
  );

  group('the form', () {
    testWidgets('asks for three things', (tester) async {
      show(form(customers: [sherif, hala]));
      await pumpView(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.newJob), findsOneWidget);
      expect(find.text(l10n.newJobSteps), findsOneWidget);
      expect(find.text(l10n.newJobCustomerTitle), findsOneWidget);
      expect(find.text(l10n.newJobPickCustomer), findsOneWidget);
      expect(find.text(l10n.newJobFromContacts), findsOneWidget);
      expect(find.text(l10n.newJobNewCustomer), findsOneWidget);
      expect(find.text(l10n.newJobProblemTitle), findsOneWidget);
      expect(find.text(l10n.jobTagRemoval), findsOneWidget);
      expect(find.text(l10n.newJobDictate), findsOneWidget);
      expect(find.text(l10n.newJobSave), findsOneWidget);
      expect(find.text(l10n.newJobSavedOffline), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text(l10n.newJobOtherTime),
        200,
        scrollable: _form,
      );
      expect(find.text(l10n.newJobScheduleTitle), findsOneWidget);
      expect(find.text(l10n.newJobSendConfirmation), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('offers only new customers when there are none yet', (
      tester,
    ) async {
      show(form());
      await pumpView(tester);

      expect(find.text(l10n.newJobPickCustomer), findsNothing);
      expect(find.text(l10n.newJobNewCustomer), findsOneWidget);
    });

    testWidgets('says what is missing', (tester) async {
      show(form(schedule: ScheduleChoice(day: today), showsErrors: true));
      await pumpView(tester);

      expect(find.text(l10n.newJobCustomerRequired), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.newJobTimeRequired),
        200,
        scrollable: _form,
      );
    });

    testWidgets('saves', (tester) async {
      show(form());
      await pumpView(tester);

      await tester.tap(find.text(l10n.newJobSave));
      await tester.pump();

      verify(() => cubit.save()).called(1);
    });

    testWidgets('shows it is saving', (tester) async {
      show(form(customer: sherif).withStatus(NewJobStatus.saving));
      await pumpView(tester);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text(l10n.newJobSave), findsNothing);
    });
  });

  group('customer', () {
    testWidgets('shows the one picked and changes them', (tester) async {
      show(form(customers: [sherif, hala], customer: sherif));
      await pumpView(tester);

      expect(find.text('م. شريف عادل'), findsOneWidget);
      expect(find.text('0100 234 5678'), findsOneWidget);
      expect(find.text(l10n.newJobPickCustomer), findsNothing);

      await tester.tap(find.text(l10n.newJobChangeCustomer));
      await tester.pumpAndSettle();
      expect(find.text(l10n.newJobCustomerSheetTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField).last, 'هاله');
      await tester.pump();
      expect(find.text('م. شريف عادل'), findsOneWidget);

      await tester.tap(find.text('أ. هالة فتحي'));
      await tester.pumpAndSettle();

      verify(() => cubit.selectCustomer(hala)).called(1);
    });

    testWidgets('picks one from the list', (tester) async {
      show(form(customers: [sherif, hala]));
      await pumpView(tester);

      await tester.tap(find.text(l10n.newJobPickCustomer));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '0100');
      await tester.pump();
      expect(find.text('أ. هالة فتحي'), findsNothing);

      await tester.tap(find.text('م. شريف عادل'));
      await tester.pumpAndSettle();

      verify(() => cubit.selectCustomer(sherif)).called(1);
    });

    testWidgets('says when no customer matches', (tester) async {
      show(form(customers: [sherif]));
      await pumpView(tester);

      await tester.tap(find.text(l10n.newJobPickCustomer));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'زياد');
      await tester.pump();

      expect(find.text(l10n.newJobNoCustomerMatch), findsOneWidget);
    });

    for (final (label, location) in [
      (l10n.newJobNewCustomer, AppRoutes.newCustomer),
      (l10n.newJobFromContacts, AppRoutes.newCustomerFromContacts),
    ]) {
      testWidgets('adds a customer: $label', (tester) async {
        show(form());
        await pumpView(tester);

        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        final added = tester.element(find.text(AppRoutes.newCustomer));
        expect(GoRouterState.of(added).uri.toString(), location);
        GoRouter.of(added).pop(hala);
        await tester.pumpAndSettle();

        verify(() => cubit.selectCustomer(hala)).called(1);
      });
    }

    testWidgets('keeps the form as it was when adding is cancelled', (
      tester,
    ) async {
      show(form());
      await pumpView(tester);

      await tester.tap(find.text(l10n.newJobNewCustomer));
      await tester.pumpAndSettle();
      GoRouter.of(tester.element(find.text(AppRoutes.newCustomer))).pop();
      await tester.pumpAndSettle();

      verifyNever(() => cubit.selectCustomer(any()));
    });
  });

  group('problem', () {
    testWidgets('picks problems and takes the details', (tester) async {
      show(form(tags: [JobTag.installation]));
      await pumpView(tester);

      await tester.tap(find.text(l10n.jobTagCleaning));
      verify(() => cubit.toggleTag(JobTag.cleaning)).called(1);

      await tester.enterText(find.byType(TextField), 'العميل جايب الوحدة');
      verify(() => cubit.editDescription('العميل جايب الوحدة')).called(1);
    });

    testWidgets('shows the count only near the limit', (tester) async {
      show(form(description: 'ا' * 10));
      await pumpView(tester);
      expect(find.text('10/${Job.maxDescriptionLength}'), findsNothing);

      show(form(description: 'ا' * 950));
      await pumpView(tester);
      expect(find.text('950/${Job.maxDescriptionLength}'), findsOneWidget);
    });

    testWidgets('writes down what is said', (tester) async {
      whenListen(
        cubit,
        Stream.fromIterable([
          form(isListening: true),
          form(isListening: true, description: 'التكييف بيفصل'),
        ]),
        initialState: form(),
      );
      await pumpView(tester);

      await tester.tap(find.text(l10n.newJobDictate));
      await tester.pump();

      verify(() => cubit.toggleListening()).called(1);
      expect(find.text(l10n.newJobListening), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'التكييف بيفصل',
      );
      expect(find.text(l10n.newJobSpeechUnavailable), findsNothing);
    });

    testWidgets('says when the phone cannot take dictation', (tester) async {
      when(() => cubit.toggleListening()).thenAnswer((_) async => false);
      show(form());
      await pumpView(tester);

      await tester.tap(find.text(l10n.newJobDictate));
      await tester.pump();

      expect(find.text(l10n.newJobSpeechUnavailable), findsOneWidget);
    });
  });

  group('schedule', () {
    testWidgets('picks the day and time', (tester) async {
      show(form());
      await pumpView(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.newJobOtherTime),
        200,
        scrollable: _form,
      );
      await tester.ensureVisible(find.text(l10n.today));
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.today));

      verify(() => cubit.changeSchedule(ScheduleChoice(day: today))).called(1);
    });

    testWidgets('offers the WhatsApp confirmation with a phone and date', (
      tester,
    ) async {
      show(form(customer: sherif, schedule: oneOClock));
      await pumpView(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.newJobSendConfirmation),
        200,
        scrollable: _form,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(l10n.newJobSendConfirmation));

      verify(() => cubit.setSendConfirmation(send: false)).called(1);
    });
  });

  group('after saving', () {
    NewJobState saved({required bool confirm}) =>
        form(
          customer: sherif,
          tags: [JobTag.installation],
          schedule: oneOClock,
          sendConfirmation: confirm,
        ).withStatus(
          NewJobStatus.saved,
          saved: Job(
            id: 'job-9',
            customerId: 'sherif',
            tags: const [JobTag.installation],
            scheduledAt: DateTime(2026, 10, 2, 13),
            createdAt: today,
            updatedAt: today,
          ),
        );

    testWidgets('opens the job and sends the confirmation', (tester) async {
      whenListen(
        cubit,
        Stream.value(saved(confirm: true)),
        initialState: form(customer: sherif, schedule: oneOClock),
      );
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.job('job-9')), findsOneWidget);
      final text =
          verify(
                () => apps.whatsApp(
                  text: captureAny(named: 'text'),
                  to: sherif.phone,
                ),
              ).captured.single
              as String;
      expect(text, contains('أهلاً م. شريف عادل'));
      expect(text, contains('النهارده الساعة 1:00 الضهر'));
      expect(text, contains(l10n.jobTagInstallation));
      expect(text, endsWith('محمود عبد الله'));
    });

    testWidgets('opens the job without a message when unticked', (
      tester,
    ) async {
      whenListen(
        cubit,
        Stream.value(saved(confirm: false)),
        initialState: form(customer: sherif, schedule: oneOClock),
      );
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.job('job-9')), findsOneWidget);
      verifyNever(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      );
    });

    testWidgets('says when WhatsApp did not open, over the job', (
      tester,
    ) async {
      when(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => false);
      whenListen(
        cubit,
        Stream.value(saved(confirm: true)),
        initialState: form(customer: sherif, schedule: oneOClock),
      );
      await pumpView(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.job('job-9')), findsOneWidget);
      expect(find.text(l10n.whatsappFailed), findsOneWidget);

      await tester.tap(find.text(l10n.retry));
      await tester.pumpAndSettle();

      verify(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: sherif.phone,
        ),
      ).called(2);
    });

    testWidgets('says when saving failed', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          form(customer: sherif).withStatus(
            NewJobStatus.failed,
            failure: const UnexpectedFailure(),
          ),
        ),
        initialState: form(customer: sherif),
      );
      await pumpView(tester);
      await tester.pump();

      expect(find.text(l10n.errorUnexpected), findsOneWidget);
      expect(find.text(AppRoutes.job('job-9')), findsNothing);
    });
  });

  group('on the real database', () {
    testTechnicianApp('records a job and confirms it on WhatsApp', (
      tester,
      app,
    ) async {
      await tester.runAsync(() async {
        await seedCustomer(app, 'م. شريف عادل', phone: '01002345678');
        await seedCustomer(app, 'أ. هالة فتحي');
      });
      await app.pump(tester, location: AppRoutes.technicianJobs);

      await tester.tap(find.text(l10n.newJob));
      await app.settle(tester);
      expect(find.byType(NewJobPage), findsOneWidget);

      await tester.tap(find.text(l10n.newJobSave));
      await app.settle(tester);
      expect(find.text(l10n.newJobCustomerRequired), findsOneWidget);

      await tester.tap(find.text(l10n.newJobPickCustomer));
      await app.settle(tester);
      await tester.tap(find.text('م. شريف عادل'));
      await app.settle(tester);
      await tester.tap(find.text(l10n.jobTagCleaning));
      await tester.tap(find.text(l10n.jobTagFreon));
      await tester.enterText(find.byType(TextField), 'التكييف في الصالة');
      await app.settle(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.newJobOtherTime),
        200,
        scrollable: _form,
      );
      await tester.tap(find.text(l10n.newJobTimeNoon));
      await app.settle(tester);
      await tester.scrollUntilVisible(
        find.text(l10n.newJobSendConfirmation),
        200,
        scrollable: _form,
      );

      await tester.tap(find.text(l10n.newJobSave));
      await app.settle(tester);

      final page = tester.widget<JobPage>(find.byType(JobPage));
      final details = await tester.runAsync(
        () => app.jobs.watchJob(page.jobId).first,
      );
      final job = details!.job;
      expect(details.customer.name, 'م. شريف عادل');
      expect(job.tags, [JobTag.cleaning, JobTag.freon]);
      expect(job.description, 'التكييف في الصالة');
      final now = DateTime.now();
      expect(job.scheduledAt, DateTime(now.year, now.month, now.day, 13));
      final text =
          verify(
                () => app.apps.whatsApp(
                  text: captureAny(named: 'text'),
                  to: PhoneNumber.tryParse('01002345678'),
                ),
              ).captured.single
              as String;
      expect(text, contains('النهارده الساعة 1:00 الضهر'));

      app.router(tester).pop();
      await app.settle(tester);
      expect(find.byType(JobsView), findsOneWidget);
      expect(find.text('م. شريف عادل'), findsOneWidget);
    });

    testTechnicianApp('starts with the customer it was opened for', (
      tester,
      app,
    ) async {
      late String hala;
      await tester.runAsync(() async {
        hala = await seedCustomer(app, 'أ. هالة فتحي');
      });
      await app.pump(tester);

      unawaited(app.router(tester).push(AppRoutes.newJobFor(hala)));
      await app.settle(tester);

      expect(find.text('أ. هالة فتحي'), findsOneWidget);
      expect(find.text(l10n.newJobChangeCustomer), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.newJobClose));
      await app.settle(tester);
      expect(find.byType(NewJobPage), findsNothing);
    });
  });
}

/// The form's list, as opposed to the description field's own scrolling.
final Finder _form = find
    .descendant(of: find.byType(NewJobView), matching: find.byType(Scrollable))
    .first;
