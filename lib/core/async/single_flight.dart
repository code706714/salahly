/// Runs a fetch one at a time without losing a call.
///
/// A call while the fetch runs doesn't start a second one; it makes the
/// running one go once more when it ends, and waits for that run. So the
/// caller always gets data fetched after its call, for example after an
/// action changed what the server returns.
class SingleFlight {
  SingleFlight(this._task);

  final Future<void> Function() _task;
  Future<void>? _running;
  bool _again = false;

  Future<void> call() {
    if (_running case final running?) {
      _again = true;
      return running;
    }
    return _running = _run();
  }

  Future<void> _run() async {
    try {
      do {
        _again = false;
        await _task();
      } while (_again);
    } finally {
      _running = null;
    }
  }
}
