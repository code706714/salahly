import 'dart:async';

import 'package:salahly/core/live/live_updates.dart';

/// Live updates the test fires by hand.
class FakeLiveUpdates implements LiveUpdates {
  final _controller = StreamController<void>.broadcast(sync: true);

  void fire() => _controller.add(null);

  @override
  Stream<void> get changes => _controller.stream;
}
