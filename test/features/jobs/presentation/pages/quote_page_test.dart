import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/presentation/cubit/quote_cubit.dart';
import 'package:salahly/features/jobs/presentation/pages/quote_page.dart';
import 'package:salahly/features/jobs/presentation/quote/quote_message.dart';

import '../../../../helpers/job_details_fixtures.dart';
import '../../../../helpers/job_fixtures.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pushed_view.dart';
import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

class _MockQuoteCubit extends MockCubit<QuoteState> implements QuoteCubit {}

void main() {
  late _MockQuoteCubit cubit;
  late MockSessionCubit session;
  late MockExternalApps apps;
  final phone = PhoneNumber.tryParse('01002345678')!;
  final drafts = [
    for (final item in sampleItems)
      JobItemDraft(
        id: item.id,
        title: item.title,
        unitPricePiastres: item.unitPricePiastres,
        quantity: item.quantity,
      ),
  ];
  const suggestions = [
    ItemSuggestion(title: 'تنظيف وحدة', unitPricePiastres: 25000),
    ItemSuggestion(title: 'شحن فريون', unitPricePiastres: 60000),
  ];

  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('ar');
    registerFallbackValue(phone);
    registerFallbackValue(const JobItemDraft(title: '', unitPricePiastres: 0));
  });

  setUp(() {
    cubit = _MockQuoteCubit();
    session = MockSessionCubit();
    apps = MockExternalApps();
    when(() => session.state).thenReturn(
      const SessionReady(
        user: TechnicianApp.user,
        profile: TechnicianApp.profile,
      ),
    );
    when(() => cubit.saveDraft()).thenAnswer((_) async => true);
    when(() => cubit.send()).thenAnswer((_) async => true);
    when(() => cubit.markAccepted()).thenAnswer((_) async => true);
    when(
      () => apps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
  });

  QuoteState quote({
    JobStatus status = JobStatus.confirmed,
    QuoteStatus quoteStatus = QuoteStatus.draft,
    List<JobItemDraft>? items,
    bool isDirty = false,
    bool isSaving = false,
    JobSource source = JobSource.manual,
  }) => QuoteState(
    status: JobDetailsStatus.ready,
    details: testDetails(
      job: testJob(
        source: source,
        status: status,
        tags: [JobTag.installation],
        quoteStatus: quoteStatus,
      ),
    ),
    items: items ?? drafts,
    suggestions: suggestions,
    isDirty: isDirty,
    isSaving: isSaving,
  );

  void show(QuoteState state) => when(() => cubit.state).thenReturn(state);

  Future<void> pumpPage(
    WidgetTester tester, {
    Widget view = const QuoteView(),
  }) => tester.pumpApp(
    view,
    repositories: [RepositoryProvider<ExternalApps>.value(value: apps)],
    blocs: [
      BlocProvider<QuoteCubit>.value(value: cubit),
      BlocProvider<SessionCubit>.value(value: session),
    ],
  );

  String messageFor(QuoteState state, {bool toBook = false}) => quoteMessage(
    l10n,
    customerName: 'م. شريف عادل',
    items: state.items,
    validDays: state.validDays,
    toBook: toBook,
    technicianName: 'محمود عبد الله',
    technicianPhone: phone,
  );

  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
  }

  group('states', () {
    testWidgets('shows nothing while loading', (tester) async {
      show(const QuoteState());
      await pumpPage(tester);
      expect(find.text(l10n.quoteTitle), findsNothing);
    });

    testWidgets('says when the job is not on this phone', (tester) async {
      show(const QuoteState(status: JobDetailsStatus.deleted));
      await pumpPage(tester);
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.quoteTitle), findsOneWidget);
      expect(find.text(l10n.jobPageMissing), findsOneWidget);
    });

    testWidgets('shows nothing while signing out', (tester) async {
      when(() => session.state).thenReturn(const SessionSignedOut());
      show(quote());
      await pumpPage(tester);
      expect(find.text(l10n.quoteTitle), findsNothing);
    });

    testWidgets('lists the lines, the total and the message', (tester) async {
      final state = quote();
      show(state);
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.quoteTitle), findsOneWidget);
      expect(
        find.text('م. شريف عادل · ${l10n.jobTagInstallation}'),
        findsOneWidget,
      );
      expect(find.text(sampleItems[1].title), findsOneWidget);
      expect(find.text(l10n.quoteUnitPrice(4, '100')), findsOneWidget);
      expect(find.text('400'), findsOneWidget);
      expect(find.text(l10n.quoteValidFor(3)), findsOneWidget);
      expect(find.text(l10n.quoteSend), findsOneWidget);
      expect(find.text(l10n.quoteSaveDraft), findsOneWidget);

      await scrollTo(tester, find.text(messageFor(state)));
      expect(tester.takeException(), isNull);
      expect(find.text(l10n.quotePreviewTitle), findsOneWidget);
    });

    testWidgets('a visit not booked yet asks to book it', (tester) async {
      final state = quote(status: JobStatus.unconfirmed);
      show(state);
      await pumpPage(tester);
      await scrollTo(tester, find.text(messageFor(state, toBook: true)));
      expect(find.textContaining('أثبّتلك المعاد'), findsOneWidget);
    });

    testWidgets('an empty quote cannot be sent', (tester) async {
      show(quote(items: const []));
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.quoteEmpty), findsOneWidget);
      expect(find.text(l10n.quotePreviewTitle), findsNothing);
      await tester.tap(find.text(l10n.quoteSend));
      await tester.pump();
      verifyNever(() => cubit.send());
    });

    testWidgets('a sent quote waits for the customer', (tester) async {
      show(quote(quoteStatus: QuoteStatus.sent));
      await pumpPage(tester);

      expect(find.text(l10n.jobQuoteSent), findsOneWidget);
      await tester.tap(find.text(l10n.quoteMarkAccepted));
      verify(() => cubit.markAccepted()).called(1);
    });

    testWidgets('an accepted quote says so', (tester) async {
      show(quote(quoteStatus: QuoteStatus.accepted));
      await pumpPage(tester);
      expect(find.text(l10n.quoteAccepted), findsOneWidget);
      expect(find.text(l10n.quoteMarkAccepted), findsNothing);
    });

    testWidgets('says why saving failed', (tester) async {
      whenListen(
        cubit,
        Stream.value(
          quote().copyWith(failure: () => const NetworkFailure()),
        ),
        initialState: quote(),
      );
      await pumpPage(tester);
      await tester.pump();
      expect(find.text(l10n.errorNetwork), findsOneWidget);
    });
  });

  group('lines', () {
    testWidgets('steps how many, and removes a line of one', (tester) async {
      show(quote());
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.quoteIncrease).first);
      verify(() => cubit.increment(0)).called(1);
      await tester.tap(find.byTooltip(l10n.quoteDecrease));
      verify(() => cubit.decrement(1)).called(1);
      await tester.tap(find.byTooltip(l10n.quoteRemoveItem).first);
      verify(() => cubit.remove(0)).called(1);
    });

    testWidgets('stops at the most a line can have', (tester) async {
      show(
        quote(
          items: const [
            JobItemDraft(
              title: 'ماسورة',
              unitPricePiastres: 100,
              quantity: JobItem.maxQuantity,
            ),
          ],
        ),
      );
      await pumpPage(tester);

      await tester.tap(find.byTooltip(l10n.quoteIncrease));
      verifyNever(() => cubit.increment(any()));
    });

    testWidgets('changes how long the quote holds', (tester) async {
      show(quote());
      await pumpPage(tester);

      await tester.tap(find.text(l10n.quoteValidFor(3)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.quoteValidityTitle), findsOneWidget);
      await tester.tap(find.text(l10n.quoteValidityDays(7)));
      await tester.pumpAndSettle();

      verify(() => cubit.setValidDays(7)).called(1);
    });
  });

  group('adding a line', () {
    Future<void> openSheet(WidgetTester tester) async {
      show(quote());
      await pumpPage(tester);
      await scrollTo(tester, find.text(l10n.quoteAddItem));
      await tester.tap(find.text(l10n.quoteAddItem));
      await tester.pumpAndSettle();
    }

    Finder field(String label) => find.widgetWithText(TextField, label);

    testWidgets('adds a typed line', (tester) async {
      await openSheet(tester);
      expect(tester.takeException(), isNull);

      await tester.enterText(
        field(l10n.quoteItemTitleLabel),
        ' تغيير كابستور ',
      );
      await tester.enterText(field(l10n.quoteItemPriceLabel), '1250');
      expect(find.text('1,250'), findsOneWidget);
      await tester.tap(find.text(l10n.quoteItemAdd));
      await tester.pumpAndSettle();

      verify(
        () => cubit.addItem(
          const JobItemDraft(title: 'تغيير كابستور', unitPricePiastres: 125000),
        ),
      ).called(1);
    });

    testWidgets('asks for a title and a price', (tester) async {
      await openSheet(tester);

      await tester.tap(find.text(l10n.quoteItemAdd));
      await tester.pump();

      expect(find.text(l10n.quoteItemTitleRequired), findsOneWidget);
      expect(find.text(l10n.quoteItemPriceInvalid), findsOneWidget);
      verifyNever(() => cubit.addItem(any()));
    });

    testWidgets('refuses a price above the most a line can cost', (
      tester,
    ) async {
      await openSheet(tester);

      await tester.enterText(field(l10n.quoteItemTitleLabel), 'تكييف مركزي');
      await tester.enterText(field(l10n.quoteItemPriceLabel), '2000000');
      await tester.tap(find.text(l10n.quoteItemAdd));
      await tester.pump();

      expect(find.text(l10n.quoteItemTitleRequired), findsNothing);
      expect(find.text(l10n.quoteItemPriceInvalid), findsOneWidget);
      verifyNever(() => cubit.addItem(any()));
    });

    testWidgets('picks a line used before, narrowed by the title', (
      tester,
    ) async {
      await openSheet(tester);
      expect(find.text(l10n.quoteSuggestions), findsOneWidget);
      expect(find.text('شحن فريون'), findsOneWidget);

      await tester.enterText(field(l10n.quoteItemTitleLabel), 'تنظيف');
      await tester.pump();
      expect(find.text('شحن فريون'), findsNothing);
      await tester.tap(find.text('تنظيف وحدة'));
      await tester.pumpAndSettle();

      verify(
        () => cubit.addItem(
          const JobItemDraft(title: 'تنظيف وحدة', unitPricePiastres: 25000),
        ),
      ).called(1);
    });
  });

  group('sending', () {
    testWidgets('saves it as sent and opens WhatsApp with it', (
      tester,
    ) async {
      final state = quote();
      show(state);
      await pumpPage(tester);

      await tester.tap(find.text(l10n.quoteSend));
      await tester.pumpAndSettle();

      verify(() => cubit.send()).called(1);
      verify(
        () => apps.whatsApp(text: messageFor(state), to: phone),
      ).called(1);
    });

    testWidgets('says the quote was kept when WhatsApp did not open', (
      tester,
    ) async {
      when(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      ).thenAnswer((_) async => false);
      show(quote());
      await pumpPage(tester);

      await tester.tap(find.text(l10n.quoteSend));
      await tester.pumpAndSettle();

      expect(
        find.text('${l10n.whatsappFailed} ${l10n.quoteSavedNote}'),
        findsOneWidget,
      );
    });

    testWidgets('does not open WhatsApp when saving failed', (tester) async {
      when(() => cubit.send()).thenAnswer((_) async => false);
      show(quote());
      await pumpPage(tester);

      await tester.tap(find.text(l10n.quoteSend));
      await tester.pumpAndSettle();

      verifyNever(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      );
    });

    testWidgets('waits while saving', (tester) async {
      show(quote(isSaving: true));
      await pumpPage(tester);

      await tester.tap(find.text(l10n.quoteSend));
      await tester.tap(find.text(l10n.quoteSaveDraft));
      await tester.pump();

      verifyNever(() => cubit.send());
      verifyNever(() => cubit.saveDraft());
    });
  });

  group('platform job', () {
    QuoteState platform({QuoteStatus quoteStatus = QuoteStatus.accepted}) =>
        quote(quoteStatus: quoteStatus, source: JobSource.platform);

    testWidgets('sends the price change in the app, not on WhatsApp', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(smallPhone);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      show(platform(quoteStatus: QuoteStatus.draft));
      await pumpPage(tester, view: const PushedView(QuoteView()));
      await tester.openPushedView();

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.platformJobQuoteInApp), findsOneWidget);
      expect(find.text(l10n.quoteSend), findsNothing);
      expect(find.text(l10n.quotePreviewTitle), findsNothing);
      await tester.tap(find.text(l10n.platformJobQuoteSend));
      await tester.pumpAndSettle();

      verify(() => cubit.send()).called(1);
      verifyNever(
        () => apps.whatsApp(
          text: any(named: 'text'),
          to: any(named: 'to'),
        ),
      );
      expect(find.text(PushedView.launcher), findsOneWidget);
    });

    testWidgets('stays when the price change was not sent', (tester) async {
      when(() => cubit.send()).thenAnswer((_) async => false);
      show(platform(quoteStatus: QuoteStatus.draft));
      await pumpPage(tester, view: const PushedView(QuoteView()));
      await tester.openPushedView();

      await tester.tap(find.text(l10n.platformJobQuoteSend));
      await tester.pumpAndSettle();

      expect(find.text(l10n.platformJobQuoteSend), findsOneWidget);
    });

    testWidgets('waits for the consumer, who alone says yes', (tester) async {
      show(platform(quoteStatus: QuoteStatus.sent));
      await pumpPage(tester);

      expect(find.text(l10n.jobQuoteSent), findsOneWidget);
      expect(find.text(l10n.quoteMarkAccepted), findsNothing);
    });

    testWidgets('shows the answer the consumer gave', (tester) async {
      show(platform());
      await pumpPage(tester);
      expect(find.text(l10n.quoteAccepted), findsOneWidget);

      show(platform(quoteStatus: QuoteStatus.declined));
      await pumpPage(tester);
      expect(find.text(l10n.platformJobQuoteDeclined), findsOneWidget);
      expect(find.text(l10n.platformJobQuoteDeclinedHint), findsOneWidget);
      expect(find.text(l10n.quoteMarkAccepted), findsNothing);
    });
  });

  group('leaving', () {
    testWidgets('saves a draft and leaves', (tester) async {
      show(quote());
      await pumpPage(tester, view: const PushedView(QuoteView()));
      await tester.openPushedView();

      await tester.tap(find.text(l10n.quoteSaveDraft));
      await tester.pumpAndSettle();

      verify(() => cubit.saveDraft()).called(1);
      expect(find.text(PushedView.launcher), findsOneWidget);
    });

    testWidgets('stays when the draft was not saved', (tester) async {
      when(() => cubit.saveDraft()).thenAnswer((_) async => false);
      show(quote());
      await pumpPage(tester, view: const PushedView(QuoteView()));
      await tester.openPushedView();

      await tester.tap(find.text(l10n.quoteSaveDraft));
      await tester.pumpAndSettle();

      expect(find.text(l10n.quoteTitle), findsOneWidget);
    });

    testWidgets('leaves an unchanged quote without asking', (tester) async {
      show(quote());
      await pumpPage(tester, view: const PushedView(QuoteView()));
      await tester.openPushedView();

      await tester.tap(find.byTooltip(l10n.back));
      await tester.pumpAndSettle();

      expect(find.text(PushedView.launcher), findsOneWidget);
    });

    testWidgets('asks before dropping changes', (tester) async {
      show(quote(isDirty: true));
      await pumpPage(tester, view: const PushedView(QuoteView()));
      await tester.openPushedView();

      await tester.tap(find.byTooltip(l10n.back));
      await tester.pumpAndSettle();
      expect(find.text(l10n.quoteDiscardTitle), findsOneWidget);
      await tester.tap(find.text(l10n.quoteStay));
      await tester.pumpAndSettle();
      expect(find.text(l10n.quoteTitle), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.back));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.quoteDiscard));
      await tester.pumpAndSettle();

      expect(find.text(PushedView.launcher), findsOneWidget);
      verifyNever(() => cubit.saveDraft());
    });
  });
}
