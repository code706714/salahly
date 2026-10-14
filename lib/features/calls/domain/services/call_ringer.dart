/// The sound a call makes while it rings, on the side that calls and on the
/// side that is called.
abstract interface class CallRinger {
  /// Rings until [stop]; the called side hears a ringtone, the calling side
  /// a softer tone.
  Future<void> start({required bool incoming});

  Future<void> stop();
}
