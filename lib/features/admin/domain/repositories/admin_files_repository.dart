import 'package:salahly/core/error/result.dart';

/// The buckets an admin may read from.
enum AdminBucket {
  transferProofs('transfer-proofs'),
  verificationDocs('verification-docs'),
  requestPhotos('request-photos');

  const AdminBucket(this.id);

  final String id;
}

// An interface so screens can be tested without a server.
// ignore: one_member_abstracts
abstract interface class AdminFilesRepository {
  /// A link to [path] that works for a minute, made with the admin's own
  /// session. Never log it.
  Future<Result<String>> signedUrl(AdminBucket bucket, String path);
}
