import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/signed_image_cubit.dart';

import '../../../../helpers/admin_harness.dart';
import '../../../../helpers/admin_mocks.dart';

void main() {
  late MockAdminFilesRepository repository;

  setUpAll(AdminHarness.registerFallbacks);
  setUp(() => repository = MockAdminFilesRepository());

  SignedImageCubit build() => SignedImageCubit(
    repository,
    bucket: AdminBucket.transferProofs,
    path: 'user/proof.jpg',
  );

  blocTest<SignedImageCubit, SignedImageState>(
    'makes a link to the file of its bucket',
    setUp: () => when(
      () => repository.signedUrl(AdminBucket.transferProofs, 'user/proof.jpg'),
    ).thenAnswer((_) async => const Ok('https://files.example/proof')),
    build: build,
    act: (cubit) => cubit.load(),
    expect: () => const [
      SignedImageState(),
      SignedImageState(url: 'https://files.example/proof', isLoading: false),
    ],
  );

  blocTest<SignedImageCubit, SignedImageState>(
    'says so when no link could be made, and tries again on request',
    setUp: () => when(
      () => repository.signedUrl(any(), any()),
    ).thenAnswer((_) async => const Err(NetworkFailure())),
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.load();
    },
    expect: () => const [
      SignedImageState(),
      SignedImageState(isLoading: false, failure: NetworkFailure()),
      SignedImageState(),
      SignedImageState(isLoading: false, failure: NetworkFailure()),
    ],
    verify: (_) => verify(() => repository.signedUrl(any(), any())).called(2),
  );
}
