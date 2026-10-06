import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/failures/marketplace_failures.dart';
import 'package:salahly/features/marketplace/presentation/cubit/addresses_cubit.dart';

import '../../../../helpers/consumer_screens.dart';
import '../../../../helpers/marketplace_fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockConsumerRequestsRepository requests;

  const work = ConsumerAddressDraft(
    label: 'الشغل',
    areaId: 'heliopolis',
    details: 'شارع الميرغني',
  );

  setUpAll(registerConsumerScreenFallbacks);

  setUp(() {
    requests = MockConsumerRequestsRepository();
    when(
      requests.fetchAddresses,
    ).thenAnswer((_) async => const Ok([testHome, testMomsHome]));
  });

  Future<AddressesCubit> loaded() async {
    final cubit = AddressesCubit(requests);
    await cubit.load();
    return cubit;
  }

  test('starts loading', () async {
    final cubit = AddressesCubit(requests);

    expect(cubit.state, const AddressesState());
    await cubit.close();
  });

  test('fetches the address book', () async {
    final cubit = await loaded();

    expect(cubit.state.status, AddressesStatus.ready);
    expect(cubit.state.addresses, [testHome, testMomsHome]);
    expect(cubit.state.isFull, isFalse);
    await cubit.close();
  });

  test('a failed fetch shows, and retrying fetches again', () async {
    when(
      requests.fetchAddresses,
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = await loaded();
    expect(cubit.state.status, AddressesStatus.failed);

    when(requests.fetchAddresses).thenAnswer((_) async => const Ok([]));
    final states = <AddressesStatus>[];
    final sub = cubit.stream.listen((state) => states.add(state.status));
    await cubit.retry();
    await pumpEventQueue();
    await sub.cancel();

    expect(states, [AddressesStatus.loading, AddressesStatus.ready]);
    expect(cubit.state.addresses, isEmpty);
    await cubit.close();
  });

  test('a failed refresh keeps the list', () async {
    final cubit = await loaded();
    when(
      requests.fetchAddresses,
    ).thenAnswer((_) async => const Err(NetworkFailure()));

    await cubit.load();

    expect(cubit.state.status, AddressesStatus.ready);
    expect(cubit.state.addresses, [testHome, testMomsHome]);
    await cubit.close();
  });

  test('is full at ten addresses', () async {
    when(requests.fetchAddresses).thenAnswer(
      (_) async => Ok([
        for (var i = 0; i < AddressesCubit.maxAddresses; i++)
          ConsumerAddress(
            id: 'address-$i',
            label: 'عنوان $i',
            areaId: 'nasr_city',
            details: 'شارع $i',
          ),
      ]),
    );
    final cubit = await loaded();

    expect(cubit.state.isFull, isTrue);
    await cubit.close();
  });

  test('adds a new address at the end', () async {
    when(
      () => requests.saveAddress(work),
    ).thenAnswer((_) async => const Ok('address-3'));
    final cubit = await loaded();

    expect(await cubit.save(work), isNull);

    expect(cubit.state.addresses, [
      testHome,
      testMomsHome,
      const ConsumerAddress(
        id: 'address-3',
        label: 'الشغل',
        areaId: 'heliopolis',
        details: 'شارع الميرغني',
      ),
    ]);
    await cubit.close();
  });

  test('updates an edited address in place', () async {
    when(
      () => requests.saveAddress(work, id: 'address-1'),
    ).thenAnswer((_) async => const Ok('address-1'));
    final cubit = await loaded();

    expect(await cubit.save(work, id: 'address-1'), isNull);

    expect(cubit.state.addresses, [
      const ConsumerAddress(
        id: 'address-1',
        label: 'الشغل',
        areaId: 'heliopolis',
        details: 'شارع الميرغني',
      ),
      testMomsHome,
    ]);
    await cubit.close();
  });

  test('returns why saving failed and keeps the list', () async {
    when(
      () => requests.saveAddress(any()),
    ).thenAnswer((_) async => const Err(AddressLimitFailure()));
    final cubit = await loaded();

    expect(await cubit.save(work), const AddressLimitFailure());
    expect(cubit.state.addresses, [testHome, testMomsHome]);
    await cubit.close();
  });

  test('deletes an address, marking it while deleting', () async {
    final deleted = Completer<Result<void>>();
    when(
      () => requests.deleteAddress('address-1'),
    ).thenAnswer((_) => deleted.future);
    final cubit = await loaded();

    final deleting = cubit.delete('address-1');
    expect(cubit.state.deleting, 'address-1');
    deleted.complete(const Ok(null));
    await deleting;

    expect(cubit.state.deleting, isNull);
    expect(cubit.state.addresses, [testMomsHome]);
    await cubit.close();
  });

  test('a failed delete keeps the address and says why', () async {
    when(
      () => requests.deleteAddress(any()),
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = await loaded();

    await cubit.delete('address-1');

    expect(cubit.state.addresses, [testHome, testMomsHome]);
    expect(cubit.state.deleting, isNull);
    expect(cubit.state.failure, const NetworkFailure());

    when(
      () => requests.deleteAddress(any()),
    ).thenAnswer((_) async => const Ok(null));
    final deleting = cubit.delete('address-1');
    expect(cubit.state.failure, isNull);
    await deleting;
    await cubit.close();
  });

  test('ignores answers arriving after closing', () async {
    final fetched = Completer<Result<List<ConsumerAddress>>>();
    when(requests.fetchAddresses).thenAnswer((_) => fetched.future);
    final cubit = AddressesCubit(requests);
    final loading = cubit.load();
    await cubit.close();
    fetched.complete(const Ok([testHome]));
    await loading;

    expect(cubit.state.status, AddressesStatus.loading);
  });
}
