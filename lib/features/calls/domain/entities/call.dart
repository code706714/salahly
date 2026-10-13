import 'package:equatable/equatable.dart';

/// Where a call stands on the server.
enum CallStatus { ringing, answered, ended, declined, missed }

/// The three kinds of handshake message two phones pass to set up the voice
/// link: the caller's offer, the callee's answer, and the network routes
/// each side finds ([candidate]).
enum CallSignalKind { offer, answer, candidate }

/// One handshake message. The server holds it only until the call is over.
final class CallSignal extends Equatable {
  const CallSignal({
    required this.id,
    required this.kind,
    required this.payload,
  });

  /// Orders the messages of one call.
  final int id;
  final CallSignalKind kind;
  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [id, kind, payload];
}

/// A handshake message this phone is about to send; the server numbers it.
final class CallSignalDraft extends Equatable {
  const CallSignalDraft(this.kind, this.payload);

  final CallSignalKind kind;
  final Map<String, dynamic> payload;

  @override
  List<Object?> get props => [kind, payload];
}

/// A call ringing for the person now.
final class IncomingCall extends Equatable {
  const IncomingCall({
    required this.id,
    required this.requestId,
    required this.technicianId,
    required this.callerName,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String technicianId;

  /// The technician's name, or the consumer's short name.
  final String callerName;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
    id,
    requestId,
    technicianId,
    callerName,
    createdAt,
  ];
}
