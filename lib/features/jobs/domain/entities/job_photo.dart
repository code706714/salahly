import 'package:equatable/equatable.dart';

enum PhotoKind { before, after }

/// A photo of the work, taken before or after it.
final class JobPhoto extends Equatable {
  const JobPhoto({
    required this.id,
    required this.jobId,
    required this.kind,
    required this.storagePath,
    required this.createdAt,
    this.localPath,
  });

  final String id;
  final String jobId;
  final PhotoKind kind;

  /// Where the photo is (or will be) on the server.
  final String storagePath;

  /// The copy on this phone, when there is one.
  final String? localPath;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    jobId,
    kind,
    storagePath,
    localPath,
    createdAt,
  ];
}
