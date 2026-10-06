import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/addresses_cubit.dart';
import 'package:salahly/features/marketplace/presentation/pages/addresses_page.dart';
import 'package:salahly/features/marketplace/presentation/widgets/marketplace_failure_message.dart';

import '../../../../helpers/consumer_app.dart';
import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../pump_app.dart';

void main() {
  late MockAddressesCubit cubit;

  const ready = AddressesState(
    status: AddressesStatus.ready,
    addresses: [testHome, testMomsHome],
  );

  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
    registerConsumerScreenFallbacks();
  });

  setUp(() {
    cubit = MockAddressesCubit();
    when(() => cubit.retry()).thenAnswer((_) async {});
    when(() => cubit.delete(any())).thenAnswer((_) async {});
    when(
      () => cubit.save(any(), id: any(named: 'id')),
    ).thenAnswer((_) async => null);
  });

  Future<void> pumpView(
    WidgetTester tester,
    AddressesState state, {
    ConsumerScreenBlocs? blocs,
    Stream<AddressesState>? states,
  }) async {
    if (states != null) {
      whenListen(cubit, states, initialState: state);
    } else {
      when(() => cubit.state).thenReturn(state);
    }
    await tester.pumpApp(
      BlocProvider<AddressesCubit>.value(
        value: cubit,
        child: const AddressesView(),
      ),
      blocs: (blocs ?? ConsumerScreenBlocs()).providers,
    );
  }

  testWidgets('lists the addresses with the privacy note on a small phone', (
    tester,
  ) async {
    await pumpView(tester, ready);

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.addressesTitle), findsOneWidget);
    expect(find.text('البيت'), findsOneWidget);
    expect(
      find.text('14 شارع عباس العقاد، الحي العاشر · الدور الخامس، مدينة نصر'),
      findsOneWidget,
    );
    expect(find.text('بيت ماما'), findsOneWidget);
    expect(find.text(l10n.addressesNew), findsOneWidget);
    expect(find.text(l10n.addressesPrivacy('ms')), findsOneWidget);
  });

  testWidgets('waits for the addresses', (tester) async {
    await pumpView(tester, const AddressesState());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('retries addresses that could not be fetched', (tester) async {
    await pumpView(
      tester,
      const AddressesState(status: AddressesStatus.failed),
    );

    expect(find.text(l10n.addressesLoadFailed), findsOneWidget);
    await tester.tap(find.text(l10n.consumerRetry('ms')));
    verify(() => cubit.retry()).called(1);
  });

  testWidgets('invites him to add one when there is none', (tester) async {
    await pumpView(
      tester,
      const AddressesState(status: AddressesStatus.ready),
      blocs: ConsumerScreenBlocs(
        session: testConsumerSession(honorific: Honorific.mr),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text(l10n.addressesEmpty), findsOneWidget);
    expect(find.text(l10n.addressesEmptyNote('other')), findsOneWidget);
  });

  testWidgets('offers no new address once ten are saved', (tester) async {
    await pumpView(
      tester,
      AddressesState(
        status: AddressesStatus.ready,
        addresses: [
          for (var i = 0; i < AddressesCubit.maxAddresses; i++)
            ConsumerAddress(
              id: 'a$i',
              label: 'عنوان $i',
              areaId: 'nasr_city',
              details: 'شارع $i',
            ),
        ],
      ),
    );

    await tester.scrollUntilVisible(
      find.text(l10n.consumerAddressLimit('ms')),
      200,
    );
    expect(find.text(l10n.addressesNew), findsNothing);
  });

  group('the address form', () {
    Future<void> openNew(WidgetTester tester) async {
      await pumpView(tester, ready);
      await tester.tap(find.text(l10n.addressesNew));
      await tester.pumpAndSettle();
    }

    testWidgets('fits a small phone', (tester) async {
      await openNew(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.addressesLabel), findsOneWidget);
      expect(find.text(l10n.addressesArea), findsOneWidget);
      expect(find.text(l10n.addressesDetails), findsOneWidget);
    });

    testWidgets('says what is missing', (tester) async {
      await openNew(tester);

      await tester.enterText(find.byType(TextField).last, 'ab');
      await tester.tap(find.text(l10n.addressesSave('ms')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.addressesLabelRequired('ms')), findsOneWidget);
      expect(find.text(l10n.addressesAreaRequired('ms')), findsOneWidget);
      expect(find.text(l10n.addressesDetailsRequired('ms')), findsOneWidget);
      verifyNever(() => cubit.save(any(), id: any(named: 'id')));
    });

    testWidgets('saves a new address and closes', (tester) async {
      await openNew(tester);

      await tester.enterText(find.byType(TextField).first, '  الشغل ');
      await tester.tap(find.text(l10n.addressesAreaPick('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المعادي').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'شارع 9');
      await tester.tap(find.text(l10n.addressesSave('ms')));
      await tester.pumpAndSettle();

      verify(
        () => cubit.save(
          const ConsumerAddressDraft(
            label: 'الشغل',
            areaId: 'maadi',
            details: 'شارع 9',
          ),
        ),
      ).called(1);
      expect(find.text(l10n.addressesSave('ms')), findsNothing);
    });

    testWidgets('keeps the entries and says why saving failed', (
      tester,
    ) async {
      when(
        () => cubit.save(any(), id: any(named: 'id')),
      ).thenAnswer((_) async => const AddressLimitFailure());
      await openNew(tester);

      await tester.enterText(find.byType(TextField).first, 'الشغل');
      await tester.tap(find.text(l10n.addressesAreaPick('ms')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('المعادي').last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'شارع 9');
      await tester.tap(find.text(l10n.addressesSave('ms')));
      await tester.pumpAndSettle();

      expect(
        find.text(
          consumerFailureMessage(
            l10n,
            const AddressLimitFailure(),
            honorific: 'ms',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text(l10n.addressesSave('ms')), findsOneWidget);
    });

    testWidgets('edits a saved address', (tester) async {
      await pumpView(tester, ready);

      await tester.tap(find.text('بيت ماما'));
      await tester.pumpAndSettle();
      expect(find.text(l10n.addressesEdit('ms')), findsOneWidget);
      expect(find.text('مصر الجديدة'), findsOneWidget);

      await tester.enterText(
        find.byType(TextField).last,
        'شارع النزهة، عمارة 4',
      );
      await tester.tap(find.text(l10n.addressesSave('ms')));
      await tester.pumpAndSettle();

      verify(
        () => cubit.save(
          const ConsumerAddressDraft(
            label: 'بيت ماما',
            areaId: 'heliopolis',
            details: 'شارع النزهة، عمارة 4',
          ),
          id: 'address-2',
        ),
      ).called(1);
    });
  });

  group('deleting', () {
    testWidgets('deletes once confirmed', (tester) async {
      await pumpView(tester, ready);

      await tester.tap(find.byTooltip(l10n.addressesDelete('ms')).first);
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.addressesDeleteTitle('ms', 'البيت')),
        findsOneWidget,
      );
      expect(find.text(l10n.addressesDeleteBody), findsOneWidget);

      await tester.tap(find.text(l10n.addressesDeleteConfirm('ms')));
      await tester.pumpAndSettle();

      verify(() => cubit.delete('address-1')).called(1);
    });

    testWidgets('keeps the address when she changes her mind', (
      tester,
    ) async {
      await pumpView(tester, ready);

      await tester.tap(find.byTooltip(l10n.addressesDelete('ms')).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.addressesKeep));
      await tester.pumpAndSettle();

      verifyNever(() => cubit.delete(any()));
    });

    testWidgets('shows the address being deleted', (tester) async {
      await pumpView(tester, ready.copyWith(deleting: () => 'address-1'));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip(l10n.addressesDelete('ms')), findsOneWidget);
    });

    testWidgets('says why deleting failed', (tester) async {
      final states = StreamController<AddressesState>();
      await pumpView(tester, ready, states: states.stream);

      states.add(ready.copyWith(failure: () => const NetworkFailure()));
      await tester.pump();

      expect(
        find.text(
          consumerFailureMessage(l10n, const NetworkFailure(), honorific: 'ms'),
        ),
        findsOneWidget,
      );
      await states.close();
    });
  });

  group('AddressesPage', () {
    testConsumerApp('deletes an address', (tester, app) async {
      when(
        app.requests.fetchAddresses,
      ).thenAnswer((_) async => const Ok([testHome, testMomsHome]));
      when(
        () => app.requests.deleteAddress('address-2'),
      ).thenAnswer((_) async => const Ok(null));
      await app.pump(tester);
      unawaited(app.router(tester).push(AppRoutes.consumerAddresses));
      await app.settle(tester);
      expect(find.byType(AddressesPage), findsOneWidget);

      await tester.tap(find.byTooltip(l10n.addressesDelete('ms')).last);
      await app.settle(tester);
      await tester.tap(find.text(l10n.addressesDeleteConfirm('ms')));
      await app.settle(tester);

      verify(() => app.requests.deleteAddress('address-2')).called(1);
      expect(find.text('بيت ماما'), findsNothing);
      expect(find.text('البيت'), findsOneWidget);
    });

    testConsumerApp('edits an address', (tester, app) async {
      when(
        app.requests.fetchAddresses,
      ).thenAnswer((_) async => const Ok([testHome]));
      when(
        () => app.requests.saveAddress(any(), id: 'address-1'),
      ).thenAnswer((_) async => const Ok('address-1'));
      await app.pump(tester);
      unawaited(app.router(tester).push(AppRoutes.consumerAddresses));
      await app.settle(tester);

      await tester.tap(find.text('البيت'));
      await app.settle(tester);
      await tester.enterText(find.byType(TextField).first, 'شقتي');
      await tester.tap(find.text(l10n.addressesSave('ms')));
      await app.settle(tester);
      await tester.pump(const Duration(seconds: 1));

      verify(
        () => app.requests.saveAddress(
          ConsumerAddressDraft(
            label: 'شقتي',
            areaId: 'nasr_city',
            details: testHome.details,
          ),
          id: 'address-1',
        ),
      ).called(1);
      expect(find.text('شقتي'), findsOneWidget);
      expect(find.text('البيت'), findsNothing);
    });
  });
}
