import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/presentation/cubit/customers_cubit.dart';

import '../../../../helpers/customer_fixtures.dart';
import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockCustomersRepository customers;
  late Map<DateTime, StreamController<List<CustomerSummary>>> days;
  late DateTime now;

  setUp(() {
    customers = MockCustomersRepository();
    days = {};
    now = DateTime(2026, 10, 2, 11);
    when(
      () => customers.watchCustomers(today: any(named: 'today')),
    ).thenAnswer(
      (invocation) => days
          .putIfAbsent(
            invocation.namedArguments[#today] as DateTime,
            StreamController.broadcast,
          )
          .stream,
    );
  });

  CustomersCubit build() => CustomersCubit(
    customers: customers,
    areas: TestAreas.all,
    clock: () => now,
  )..start();

  final karim = testCustomerSummary(
    testCustomer(areaId: 'heliopolis', address: '7 شارع الحجاز'),
    owedPiastres: 120000,
  );
  final sohair = testCustomerSummary(
    testCustomer(
      id: 'customer-2',
      name: 'مدام سهير عبد الله',
      phone: '01001234567',
      areaId: 'nasr_city',
    ),
    nextServiceOn: DateTime(2026, 11),
  );
  final nourhan = testCustomerSummary(
    testCustomer(
      id: 'customer-3',
      name: 'نورهان م.',
      phone: null,
      source: CustomerSource.platform,
    ),
    nextServiceOn: DateTime(2026, 9, 20),
  );
  final essam = testCustomerSummary(
    testCustomer(id: 'customer-4', name: 'أ. عصام بدر', phone: null),
    nextServiceOn: DateTime(2026, 11, 2),
  );
  final everyone = [karim, sohair, nourhan, essam];

  Future<CustomersCubit> loaded() async {
    final cubit = build();
    days[DateTime(2026, 10, 2)]!.add(everyone);
    await pumpEventQueue();
    return cubit;
  }

  test('watches the customers from the start of the local day', () async {
    final cubit = build();

    verify(
      () => customers.watchCustomers(today: DateTime(2026, 10, 2)),
    ).called(1);
    expect(cubit.state.isLoading, isTrue);
    expect(cubit.state.isEmpty, isFalse);

    days[DateTime(2026, 10, 2)]!.add(everyone);
    await pumpEventQueue();

    expect(cubit.state.isLoading, isFalse);
    expect(cubit.state.customers, everyone);
    expect(cubit.state.visible, everyone);
    await cubit.close();
  });

  test('knows when there are no customers yet', () async {
    final cubit = build();
    days[DateTime(2026, 10, 2)]!.add([]);
    await pumpEventQueue();

    expect(cubit.state.isEmpty, isTrue);
    await cubit.close();
  });

  test('follows the next day after midnight', () {
    fakeAsync((async) {
      final cubit = build();
      days[DateTime(2026, 10, 2)]!.add(everyone);
      async.flushMicrotasks();

      now = DateTime(2026, 10, 3, 0, 0, 1);
      async.elapse(const Duration(hours: 13));

      expect(cubit.state.today, DateTime(2026, 10, 3));
      verify(
        () => customers.watchCustomers(today: DateTime(2026, 10, 3)),
      ).called(1);
      days[DateTime(2026, 10, 3)]!.add([karim]);
      async.flushMicrotasks();
      expect(cubit.state.customers, [karim]);

      unawaited(cubit.close());
      async.flushMicrotasks();
    });
  });

  test('stops watching once closed', () async {
    final cubit = await loaded();
    await cubit.close();

    expect(days[DateTime(2026, 10, 2)]!.hasListener, isFalse);
  });

  blocTest<CustomersCubit, CustomersState>(
    'reports errors from the database',
    build: () => CustomersCubit(customers: customers, clock: () => now),
    act: (cubit) {
      cubit.start();
      days[DateTime(2026, 10, 2)]!.addError(StateError('db'));
    },
    errors: () => [isA<StateError>()],
  );

  group('filters', () {
    test('count who each chip would keep', () async {
      final cubit = await loaded();

      expect(cubit.state.count(CustomerFilter.all), 4);
      expect(cubit.state.count(CustomerFilter.owing), 1);
      expect(cubit.state.count(CustomerFilter.platform), 1);
      // Within 30 days, or overdue; not 31 days away.
      expect(cubit.state.count(CustomerFilter.cleaningDue), 2);
      await cubit.close();
    });

    test('keep only the customers they are about', () async {
      final cubit = await loaded();

      cubit.filterChanged(CustomerFilter.owing);
      expect(cubit.state.visible, [karim]);
      cubit.filterChanged(CustomerFilter.platform);
      expect(cubit.state.visible, [nourhan]);
      cubit.filterChanged(CustomerFilter.cleaningDue);
      expect(cubit.state.visible, [sohair, nourhan]);
      cubit.filterChanged(CustomerFilter.all);
      expect(cubit.state.visible, everyone);
      await cubit.close();
    });

    test('fall back to everyone once their chip is empty', () async {
      final cubit = await loaded()
        ..filterChanged(CustomerFilter.owing);

      days[DateTime(2026, 10, 2)]!.add([sohair, nourhan]);
      await pumpEventQueue();

      expect(cubit.state.filter, CustomerFilter.owing);
      expect(cubit.state.activeFilter, CustomerFilter.all);
      expect(cubit.state.visible, [sohair, nourhan]);
      await cubit.close();
    });
  });

  group('search', () {
    Future<List<CustomerSummary>> search(String query) async {
      final cubit = await loaded();
      cubit.queryChanged(query);
      final visible = cubit.state.visible;
      await cubit.close();
      return visible;
    }

    test('finds by name, folding the letters people mix up', () async {
      expect(await search('سهير'), [sohair]);
      expect(await search('  عصام   بدر '), [essam]);
      expect(await search('عبد الله'), [sohair]);
      expect(await search('اصام'), isEmpty);
      expect(await search('أ.'), [karim, essam]);
    });

    test('folds alef and taa marbuta both ways', () async {
      final cubit = build();
      final hoda = testCustomerSummary(
        testCustomer(id: 'h', name: 'أ. هدى الجزيرة', phone: null),
      );
      days[DateTime(2026, 10, 2)]!.add([hoda]);
      await pumpEventQueue();

      cubit.queryChanged('هدي الجزيره');
      expect(cubit.state.visible, [hoda]);
      cubit.queryChanged('ا. هدى');
      expect(cubit.state.visible, [hoda]);
      await cubit.close();
    });

    test('finds by area name and address', () async {
      expect(await search('مدينه نصر'), [sohair]);
      expect(await search('الحجاز'), [karim]);
    });

    test('finds by phone number however it is typed', () async {
      expect(await search('0122'), [karim]);
      expect(await search('870 3314'), [karim]);
      expect(await search('+20 100 123'), [sohair]);
      expect(await search('٠١٠٠١٢'), [sohair]);
      expect(await search('0199'), isEmpty);
    });

    test('combines with the filter', () async {
      final cubit = await loaded()
        ..filterChanged(CustomerFilter.cleaningDue)
        ..queryChanged('نورهان');

      expect(cubit.state.visible, [nourhan]);
      cubit.queryChanged('كريم');
      expect(cubit.state.visible, isEmpty);
      await cubit.close();
    });

    test('finds by area names that load later', () async {
      final cubit = CustomersCubit(customers: customers, clock: () => now)
        ..start();
      days[DateTime(2026, 10, 2)]!.add(everyone);
      await pumpEventQueue();
      cubit.queryChanged('مصر الجديدة');
      expect(cubit.state.visible, isEmpty);

      cubit.areasChanged(TestAreas.all);

      expect(cubit.state.visible, [karim]);
      await cubit.close();
    });
  });
}
