import 'package:salahly/features/calls/domain/services/call_ringer.dart';

/// A [CallRinger] that only remembers what it was told.
class FakeCallRinger implements CallRinger {
  /// Whether it rings now, and for which side; null when quiet.
  bool? ringingIncoming;
  int starts = 0;

  @override
  Future<void> start({required bool incoming}) async {
    ringingIncoming = incoming;
    starts++;
  }

  @override
  Future<void> stop() async => ringingIncoming = null;
}
