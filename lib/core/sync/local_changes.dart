import 'dart:async';

/// Tells the sync that something was saved locally and should be sent.
class LocalChanges {
  final _changes = StreamController<void>.broadcast(sync: true);

  Stream<void> get stream => _changes.stream;

  void notify() => _changes.add(null);
}
