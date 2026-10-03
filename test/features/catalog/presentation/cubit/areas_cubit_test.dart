import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockCatalogRepository catalog;

  setUp(() => catalog = MockCatalogRepository());

  test('loads the areas and names them by id', () async {
    when(
      catalog.fetchAreas,
    ).thenAnswer((_) async => const Ok(TestAreas.all));
    final cubit = AreasCubit(catalog);

    await cubit.load();

    expect(cubit.state.areas, TestAreas.all);
    expect(cubit.state.nameOf('heliopolis'), 'مصر الجديدة');
    expect(cubit.state.nameOf('unknown'), isNull);
    expect(cubit.state.nameOf(null), isNull);
    await cubit.close();
  });

  test('stays empty when the areas cannot be fetched, and retries', () async {
    when(
      catalog.fetchAreas,
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = AreasCubit(catalog);

    await cubit.load();
    expect(cubit.state.areas, isEmpty);

    when(
      catalog.fetchAreas,
    ).thenAnswer((_) async => const Ok(TestAreas.all));
    await cubit.load();
    expect(cubit.state.areas, TestAreas.all);
    await cubit.close();
  });

  test('fetches once, even when asked again while loading', () async {
    final reply = Completer<Result<List<ServiceArea>>>();
    when(catalog.fetchAreas).thenAnswer((_) => reply.future);
    final cubit = AreasCubit(catalog);

    final first = cubit.load();
    final second = cubit.load();
    reply.complete(const Ok(TestAreas.all));
    await Future.wait([first, second]);
    await cubit.load();

    verify(catalog.fetchAreas).called(1);
    await cubit.close();
  });
}
