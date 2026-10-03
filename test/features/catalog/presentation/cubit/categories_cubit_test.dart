import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';

import '../../../../helpers/fixtures.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockCatalogRepository catalog;

  setUp(() => catalog = MockCatalogRepository());

  test('loads the categories and names services by id', () async {
    when(
      catalog.fetchCategories,
    ).thenAnswer((_) async => const Ok(TestCategories.all));
    final cubit = CategoriesCubit(catalog);

    await cubit.load();

    expect(cubit.state.categories, TestCategories.all);
    expect(cubit.state.category('ac'), TestCategories.airConditioning);
    expect(cubit.state.category('roofing'), isNull);
    expect(cubit.state.serviceName('ac_freon_recharge'), 'شحن فريون');
    expect(cubit.state.serviceName(null), isNull);
    await cubit.close();
  });

  test('stays empty when they cannot be fetched, and retries', () async {
    when(
      catalog.fetchCategories,
    ).thenAnswer((_) async => const Err(NetworkFailure()));
    final cubit = CategoriesCubit(catalog);

    await cubit.load();
    expect(cubit.state.categories, isEmpty);

    when(
      catalog.fetchCategories,
    ).thenAnswer((_) async => const Ok(TestCategories.all));
    await cubit.load();
    await cubit.load();

    expect(cubit.state.categories, TestCategories.all);
    verify(catalog.fetchCategories).called(2);
    await cubit.close();
  });
}
