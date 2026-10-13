import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/calls/domain/entities/call.dart';

/// Maps the call functions' JSON to domain entities.
abstract final class CallModels {
  static CallSignal signal(Map<String, dynamic> json) => CallSignal(
    id: json['id'] as int,
    kind: enumFromWire(CallSignalKind.values, json['kind']),
    payload: Map<String, dynamic>.from(json['payload'] as Map),
  );

  static IncomingCall incoming(Map<String, dynamic> json) => IncomingCall(
    id: json['id'] as String,
    requestId: json['request_id'] as String,
    technicianId: json['technician_id'] as String,
    callerName: json['caller_name'] as String,
    createdAt: timeFromWire(json['created_at']),
  );
}
