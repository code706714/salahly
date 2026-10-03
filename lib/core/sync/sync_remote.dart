import 'package:equatable/equatable.dart';

/// One local row sent to the server.
final class SyncChange extends Equatable {
  const SyncChange({required this.entity, required this.id, required this.row});

  final String entity;
  final String id;
  final Map<String, dynamic> row;

  Map<String, dynamic> toJson() => {'entity': entity, 'id': id, 'row': row};

  @override
  List<Object?> get props => [entity, id, row];
}

/// A change the server refused. [serverRow] is the server's copy of the
/// row when it has one.
final class SyncRejection extends Equatable {
  const SyncRejection({
    required this.entity,
    required this.id,
    required this.code,
    this.serverRow,
  });

  factory SyncRejection.fromJson(Map<String, dynamic> json) => SyncRejection(
    entity: json['entity'] as String,
    id: json['id'] as String,
    code: json['code'] as String,
    serverRow: json['row'] as Map<String, dynamic>?,
  );

  final String entity;
  final String id;
  final String code;
  final Map<String, dynamic>? serverRow;

  @override
  List<Object?> get props => [entity, id, code, serverRow];
}

/// One server row changed since the last pull.
final class PulledRow extends Equatable {
  const PulledRow({required this.entity, required this.row});

  final String entity;
  final Map<String, dynamic> row;

  @override
  List<Object?> get props => [entity, row];
}

/// A page of server changes and where the next page starts.
final class PullPage extends Equatable {
  const PullPage({
    required this.rows,
    required this.checkpoint,
    required this.hasMore,
  });

  factory PullPage.fromJson(Map<String, dynamic> json) => PullPage(
    rows: [
      for (final change in json['changes'] as List<dynamic>)
        PulledRow(
          entity: (change as Map<String, dynamic>)['entity'] as String,
          row: change['row'] as Map<String, dynamic>,
        ),
    ],
    checkpoint: json['checkpoint'] as Map<String, dynamic>?,
    hasMore: json['has_more'] as bool,
  );

  final List<PulledRow> rows;

  /// Opaque to the app: sent back as is to get the next changes.
  final Map<String, dynamic>? checkpoint;
  final bool hasMore;

  @override
  List<Object?> get props => [rows, checkpoint, hasMore];
}

/// The server side of sync.
abstract interface class SyncRemote {
  /// The server applies at most this many changes per call.
  static const maxPushSize = 200;

  Future<List<SyncRejection>> push(List<SyncChange> changes);

  Future<PullPage> pull(Map<String, dynamic>? checkpoint);

  /// Uploads the job photo at [localPath] to [storagePath]. Succeeds when
  /// the file is already there; throws [UploadRefusedException] when the
  /// server refuses it (the daily limit).
  Future<void> uploadPhoto({
    required String storagePath,
    required String localPath,
  });
}

final class UploadRefusedException implements Exception {
  const UploadRefusedException();
}
