import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/calls/domain/entities/call.dart';

/// Voice calls between a consumer and a technician about one request, over
/// the chat's two ids. The voice itself goes phone to phone; the server only
/// rings the other side and carries the handshake.
abstract interface class CallRepository {
  /// The servers the phones use to find each other, in the shape WebRTC
  /// takes. Never fails: without the server's answer it is a public STUN
  /// server, which is enough on many networks.
  Future<List<Map<String, dynamic>>> iceServers();

  /// Rings the other side; the new call's id.
  Future<Result<String>> start(String requestId, String technicianId);

  Future<Result<void>> answer(String callId);

  /// Cancels, declines or hangs up. Ending a call already over is fine.
  Future<Result<void>> end(String callId);

  Future<Result<void>> sendSignal(String callId, CallSignalDraft signal);

  /// The call ringing for the person, or null.
  Future<Result<IncomingCall?>> pending();

  /// Every handshake message for the person in [callId], oldest first and
  /// each once, including the ones sent before listening.
  Stream<CallSignal> signals(String callId);

  /// The call's status each time it changes.
  Stream<CallStatus> statuses(String callId);
}
