import 'dart:collection';

import 'package:salahly/core/sync/sync_remote.dart';

/// A scripted server: records what the app sends and replies from queues.
class FakeSyncRemote implements SyncRemote {
  final pushes = <List<SyncChange>>[];
  final pulls = <Map<String, dynamic>?>[];
  final uploads = <String>[];

  /// Rejections returned by the next pushes, one list per push.
  final pushReplies = Queue<List<SyncRejection>>();

  /// Pages returned by the next pulls; an empty page once exhausted.
  final pages = Queue<PullPage>();

  /// Thrown by every call while set.
  Exception? failure;

  /// Thrown by uploads while set.
  Exception? uploadFailure;

  /// Run during a push or pull, before it returns; e.g. to edit locally
  /// at the same time.
  Future<void> Function()? duringPush;
  Future<void> Function()? duringPull;

  @override
  Future<List<SyncRejection>> push(List<SyncChange> changes) async {
    if (failure case final error?) throw error;
    pushes.add(changes);
    await duringPush?.call();
    return pushReplies.isEmpty ? const [] : pushReplies.removeFirst();
  }

  @override
  Future<PullPage> pull(Map<String, dynamic>? checkpoint) async {
    if (failure case final error?) throw error;
    pulls.add(checkpoint);
    await duringPull?.call();
    return pages.isEmpty
        ? PullPage(rows: const [], checkpoint: checkpoint, hasMore: false)
        : pages.removeFirst();
  }

  @override
  Future<void> uploadPhoto({
    required String storagePath,
    required String localPath,
  }) async {
    if (failure case final error?) throw error;
    if (uploadFailure case final error?) throw error;
    uploads.add(storagePath);
  }
}
