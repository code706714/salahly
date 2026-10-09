import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/domain/entities/service_category.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_offering.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/technician_offering_cubit.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockTechnicianRequestsRepository requests;
  const offering = TechnicianOffering(
    services: [
      ServicePrice(serviceId: 'ac_inspection', startingPricePiastres: 12000),
    ],
    areaIds: {'nasr_city'},
    workDays: {6, 7},
    radiusKm: 15,
  );
  const open = [TestCategories.airConditioning, TestCategories.plumbing];

  setUpAll(() => registerFallbackValue(offering));

  setUp(() => requests = MockTechnicianRequestsRepository());

  TechnicianOfferingCubit build() =>
      TechnicianOfferingCubit(requests)..useCategories(open);

  Future<TechnicianOfferingCubit> loaded() async {
    when(requests.fetchOffering).thenAnswer((_) async => const Ok(offering));
    final cubit = build();
    await cubit.load();
    return cubit;
  }

  group('loading', () {
    test('starts loading', () {
      expect(build().state.status, OfferingStatus.loading);
    });

    test('shows what the technician offers now', () async {
      final cubit = await loaded();

      expect(cubit.state.status, OfferingStatus.editing);
      expect(cubit.state.selectedServiceIds, {'ac_inspection'});
      expect(cubit.state.priceTexts, {'ac_inspection': '120'});
      expect(cubit.state.areaIds, {'nasr_city'});
      expect(cubit.state.workDays, {6, 7});
      expect(cubit.state.radiusKm, 15);
      await cubit.close();
    });

    test('takes 10 km when none was set', () async {
      when(requests.fetchOffering).thenAnswer(
        (_) async => const Ok(
          TechnicianOffering(services: [], areaIds: {}, workDays: {}),
        ),
      );
      final cubit = build();

      await cubit.load();

      expect(cubit.state.radiusKm, 10);
      await cubit.close();
    });

    test('fails, then loads again on retry', () async {
      when(
        requests.fetchOffering,
      ).thenAnswer((_) async => const Err(NetworkFailure()));
      final cubit = build();

      await cubit.load();
      expect(cubit.state.status, OfferingStatus.failed);
      expect(cubit.state.failure, const NetworkFailure());

      when(requests.fetchOffering).thenAnswer((_) async => const Ok(offering));
      await cubit.load();

      expect(cubit.state.status, OfferingStatus.editing);
      expect(cubit.state.failure, isNull);
      await cubit.close();
    });
  });

  group('editing', () {
    test('ticking a service fills in its suggested price', () async {
      final cubit = await loaded();
      final leak = CatalogServiceFixture.leakRepair;

      cubit.serviceToggled(leak);

      expect(cubit.state.selectedServiceIds, contains(leak.id));
      expect(cubit.state.priceTexts[leak.id], '250');

      cubit
        ..priceChanged(leak.id, '300')
        ..serviceToggled(leak)
        ..serviceToggled(leak);
      expect(cubit.state.priceTexts[leak.id], '300');
      await cubit.close();
    });

    test('toggles areas, days and the radius', () async {
      final cubit = await loaded();

      cubit
        ..areaToggled('heliopolis')
        ..areaToggled('nasr_city')
        ..workDayToggled(1)
        ..workDayToggled(6)
        ..radiusChanged(5);

      expect(cubit.state.areaIds, {'heliopolis'});
      expect(cubit.state.workDays, {7, 1});
      expect(cubit.state.radiusKm, 5);
      await cubit.close();
    });
  });

  group('saving', () {
    test(
      'sends what is on screen and says how many requests it brought',
      () async {
        final cubit = await loaded();
        when(() => requests.updateOffering(any())).thenAnswer(
          (_) async => const Ok(2),
        );
        cubit
          ..serviceToggled(CatalogServiceFixture.leakRepair)
          ..areaToggled('heliopolis');

        final saved = await cubit.save();

        expect(saved, isTrue);
        expect(cubit.state.status, OfferingStatus.saved);
        expect(cubit.state.handedOver, 2);
        final sent =
            verify(() => requests.updateOffering(captureAny())).captured.single
                as TechnicianOffering;
        expect(sent.services, [
          const ServicePrice(
            serviceId: 'ac_inspection',
            startingPricePiastres: 12000,
          ),
          const ServicePrice(
            serviceId: 'plumbing_leak_repair',
            startingPricePiastres: 25000,
          ),
        ]);
        expect(sent.areaIds, {'nasr_city', 'heliopolis'});
        expect(sent.workDays, {6, 7});
        expect(sent.radiusKm, 15);
        await cubit.close();
      },
    );

    test('leaves out services of a trade that is not open', () async {
      when(requests.fetchOffering).thenAnswer(
        (_) async => const Ok(
          TechnicianOffering(
            services: [
              ServicePrice(
                serviceId: 'ac_inspection',
                startingPricePiastres: 12000,
              ),
              ServicePrice(
                serviceId: 'old_service',
                startingPricePiastres: 10000,
              ),
            ],
            areaIds: {'nasr_city'},
            workDays: {1},
          ),
        ),
      );
      when(
        () => requests.updateOffering(any()),
      ).thenAnswer((_) async => const Ok(0));
      final cubit = build();
      await cubit.load();

      await cubit.save();

      final sent =
          verify(() => requests.updateOffering(captureAny())).captured.single
              as TechnicianOffering;
      expect(sent.services.map((service) => service.serviceId), [
        'ac_inspection',
      ]);
      await cubit.close();
    });

    test('asks for what is missing instead of saving', () async {
      final cubit = await loaded();
      cubit
        ..priceChanged('ac_inspection', 'abc')
        ..areaToggled('nasr_city')
        ..workDayToggled(6)
        ..workDayToggled(7);

      final saved = await cubit.save();

      expect(saved, isFalse);
      expect(cubit.state.showsErrors, isTrue);
      expect(cubit.state.isServicesValid, isFalse);
      expect(cubit.state.isValid, isFalse);
      verifyNever(() => requests.updateOffering(any()));
      await cubit.close();
    });

    test('refuses a price that is zero or above a million', () async {
      final cubit = await loaded();

      cubit.priceChanged('ac_inspection', '0');
      expect(cubit.state.isServicesValid, isFalse);
      cubit.priceChanged('ac_inspection', '1000001');
      expect(cubit.state.isServicesValid, isFalse);
      cubit.priceChanged('ac_inspection', '1000000');
      expect(cubit.state.isServicesValid, isTrue);
      await cubit.close();
    });

    test('needs at least one service', () async {
      final cubit = await loaded();

      cubit.serviceToggled(CatalogServiceFixture.acInspection);

      expect(cubit.state.isServicesValid, isFalse);
      await cubit.close();
    });

    test('keeps editing when the server refuses', () async {
      final cubit = await loaded();
      when(
        () => requests.updateOffering(any()),
      ).thenAnswer((_) async => const Err(NotVerifiedFailure()));

      final saved = await cubit.save();

      expect(saved, isFalse);
      expect(cubit.state.status, OfferingStatus.editing);
      expect(cubit.state.failure, const NotVerifiedFailure());
      await cubit.close();
    });
  });
}

/// Services of the test trades, as the picker hands them to the cubit.
abstract final class CatalogServiceFixture {
  static final CatalogService acInspection =
      TestCategories.airConditioning.services.first;
  static final CatalogService leakRepair =
      TestCategories.plumbing.services.last;
}
