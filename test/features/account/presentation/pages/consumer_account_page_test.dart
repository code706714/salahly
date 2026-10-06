import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/account/presentation/pages/consumer_account_page.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/presentation/cubit/addresses_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/addresses_page.dart';

import '../../../../helpers/consumer_app.dart';
import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  late MockAddressesCubit addresses;

  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
    registerConsumerScreenFallbacks();
  });

  setUp(() {
    addresses = MockAddressesCubit();
    when(() => addresses.state).thenReturn(
      const AddressesState(
        status: AddressesStatus.ready,
        addresses: [testHome, testMomsHome],
      ),
    );
    when(addresses.load).thenAnswer((_) async {});
  });

  Future<ConsumerScreenBlocs> pumpView(
    WidgetTester tester, {
    ConsumerScreenBlocs? blocs,
  }) async {
    final scope = blocs ?? ConsumerScreenBlocs();
    when(scope.session.signOut).thenAnswer((_) async {});
    await tester.pumpApp(
      BlocProvider<AddressesCubit>.value(
        value: addresses,
        child: const ConsumerAccountView(),
      ),
      blocs: scope.providers,
      stubRoutes: [
        AppRoutes.consumerAddresses,
        AppRoutes.consumerBalance,
        AppRoutes.pastTechnicians,
        AppRoutes.consumerRequests,
        AppRoutes.terms,
        AppRoutes.privacy,
      ],
    );
    return scope;
  }

  testWidgets('shows her name, phone, requests left and what she can open '
      'on a small phone', (tester) async {
    await pumpView(
      tester,
      blocs: ConsumerScreenBlocs(
        session: testConsumerSession(requestCredits: 4),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('نورهان محمد'), findsOneWidget);
    expect(find.text('+20 111 456 7720'), findsOneWidget);
    expect(find.text(l10n.consumerAccountCreditsTitle), findsOneWidget);
    expect(find.text(l10n.consumerAccountCredits(4)), findsOneWidget);
    expect(find.text(l10n.addressesTitle), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text(l10n.pastTechniciansTitle), findsOneWidget);
    expect(find.text(l10n.consumerAccountRequestProblem), findsOneWidget);
    expect(find.text(l10n.legalTermsTitle), findsOneWidget);
    expect(find.text(l10n.legalPrivacyTitle), findsOneWidget);
    expect(find.text(l10n.consumerAccountSignOut('ms')), findsOneWidget);
  });

  testWidgets('says when no requests are left', (tester) async {
    await pumpView(
      tester,
      blocs: ConsumerScreenBlocs(
        session: testConsumerSession(requestCredits: 0),
      ),
    );

    expect(find.text(l10n.consumerAccountCredits(0)), findsOneWidget);
  });

  testWidgets('leaves out the address count until it is known', (
    tester,
  ) async {
    when(() => addresses.state).thenReturn(const AddressesState());
    await pumpView(tester);

    expect(find.text('2'), findsNothing);
  });

  for (final (row, path) in [
    (l10n.consumerAccountCreditsTitle, AppRoutes.consumerBalance),
    (l10n.pastTechniciansTitle, AppRoutes.pastTechnicians),
    (l10n.legalTermsTitle, AppRoutes.terms),
    (l10n.legalPrivacyTitle, AppRoutes.privacy),
    (l10n.consumerAccountRequestProblem, AppRoutes.consumerRequests),
  ]) {
    testWidgets('opens $path', (tester) async {
      await pumpView(tester);

      await tester.tap(find.text(row));
      await tester.pumpAndSettle();

      expect(find.text(path), findsOneWidget);
    });
  }

  testWidgets('opens the addresses and counts them again on the way back', (
    tester,
  ) async {
    await pumpView(tester);

    await tester.tap(find.text(l10n.addressesTitle));
    await tester.pumpAndSettle();
    expect(find.text(AppRoutes.consumerAddresses), findsOneWidget);
    verifyNever(addresses.load);

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    verify(addresses.load).called(1);
  });

  testWidgets('counts the addresses again when the requests change', (
    tester,
  ) async {
    final blocs = ConsumerScreenBlocs();
    final requests = StreamController<MyRequestsState>();
    whenListen(
      blocs.myRequests,
      requests.stream,
      initialState: const MyRequestsState(status: MyRequestsStatus.ready),
    );
    await pumpView(tester, blocs: blocs);

    requests.add(
      MyRequestsState(
        status: MyRequestsStatus.ready,
        requests: [testRequestSummary()],
      ),
    );
    await tester.pump();

    verify(addresses.load).called(1);
    await requests.close();
  });

  testWidgets('signs out once confirmed', (tester) async {
    final blocs = await pumpView(tester);

    await tester.tap(find.text(l10n.consumerAccountSignOut('ms')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.consumerAccountSignOutTitle('ms')), findsOneWidget);
    expect(find.text(l10n.consumerAccountSignOutBody('ms')), findsOneWidget);

    await tester.tap(find.text(l10n.consumerAccountSignOut('ms')).last);
    await tester.pumpAndSettle();

    verify(blocs.session.signOut).called(1);
  });

  testWidgets('stays signed in when he changes his mind', (tester) async {
    final blocs = await pumpView(
      tester,
      blocs: ConsumerScreenBlocs(
        session: testConsumerSession(honorific: Honorific.mr),
      ),
    );

    await tester.tap(find.text(l10n.consumerAccountSignOut('other')));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.consumerAccountSignOutTitle('other')),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.accountSignOutStay));
    await tester.pumpAndSettle();

    verifyNever(blocs.session.signOut);
  });

  testWidgets('shows nothing while signing out', (tester) async {
    await pumpView(
      tester,
      blocs: ConsumerScreenBlocs(session: const SessionSignedOut()),
    );

    expect(find.text(l10n.addressesTitle), findsNothing);
  });

  group('ConsumerAccountPage', () {
    testConsumerApp('adds an address and counts it', (tester, app) async {
      const work = ConsumerAddressDraft(
        label: 'الشغل',
        areaId: 'zamalek',
        details: 'شارع 26 يوليو',
      );
      when(
        () => app.requests.saveAddress(work),
      ).thenAnswer((_) async => const Ok('address-3'));
      await app.pump(tester, location: AppRoutes.consumerAccount);
      expect(find.byType(ConsumerAccountPage), findsOneWidget);
      expect(find.text('0'), findsOneWidget);

      await tester.tap(find.text(l10n.addressesTitle));
      await app.settle(tester);
      expect(find.byType(AddressesPage), findsOneWidget);
      await tester.tap(find.text(l10n.addressesNew));
      await app.settle(tester);
      await tester.enterText(find.byType(TextField).first, 'الشغل');
      await tester.tap(find.text(l10n.addressesAreaPick('ms')));
      await app.settle(tester);
      await tester.tap(find.text('الزمالك').last);
      await app.settle(tester);
      await tester.enterText(find.byType(TextField).last, 'شارع 26 يوليو');
      await tester.tap(find.text(l10n.addressesSave('ms')));
      await app.settle(tester);
      await tester.pump(const Duration(seconds: 1));
      verify(() => app.requests.saveAddress(work)).called(1);
      expect(find.text('الشغل'), findsOneWidget);

      when(app.requests.fetchAddresses).thenAnswer(
        (_) async => const Ok([
          ConsumerAddress(
            id: 'address-3',
            label: 'الشغل',
            areaId: 'zamalek',
            details: 'شارع 26 يوليو',
          ),
        ]),
      );
      await tester.tap(find.byTooltip(l10n.back));
      await app.settle(tester);

      expect(find.byType(ConsumerAccountPage), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });

    testConsumerApp('signs out from the phone', (tester, app) async {
      when(app.auth.signOut).thenAnswer((_) async {});
      await app.pump(tester, location: AppRoutes.consumerAccount);

      await tester.tap(find.text(l10n.consumerAccountSignOut('ms')));
      await app.settle(tester);
      await tester.tap(find.text(l10n.consumerAccountSignOut('ms')).last);
      await app.settle(tester);

      verify(app.auth.signOut).called(1);
    });
  });
}
