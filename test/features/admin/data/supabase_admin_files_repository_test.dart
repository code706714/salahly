import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/features/admin/data/repositories/supabase_admin_files_repository.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';

import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseAdminFilesRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseAdminFilesRepository(server.client);
  });

  test('makes a link of one minute to the file of its bucket', () async {
    server.body = {'signedURL': '/object/sign/transfer-proofs/u/p.jpg?token=t'};

    final url = valueOf(
      await repository.signedUrl(AdminBucket.transferProofs, 'u/p.jpg'),
    );

    expect(server.last.method, 'POST');
    expect(
      server.last.url.path,
      '/storage/v1/object/sign/transfer-proofs/u/p.jpg',
    );
    expect(server.lastParams, {'expiresIn': 60});
    expect(url, contains('token=t'));
    expect(SupabaseAdminFilesRepository.linkLifetime, 60);
  });

  test('reads each bucket by its id', () {
    expect(
      AdminBucket.values.map((bucket) => bucket.id),
      ['transfer-proofs', 'verification-docs', 'request-photos'],
    );
  });

  test('says so when the link could not be made', () async {
    server.offline = true;

    expect(
      await repository.signedUrl(AdminBucket.verificationDocs, 'u/f.jpg'),
      failsWith(const NetworkFailure()),
    );
  });
}
