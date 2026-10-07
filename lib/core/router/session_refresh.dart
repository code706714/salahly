import 'dart:async';

import 'package:flutter/foundation.dart';

/// Notifies on every session change, to re-run the router's redirects.
class SessionRefresh extends ChangeNotifier {
  SessionRefresh(Stream<Object?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<Object?> _subscription;

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
