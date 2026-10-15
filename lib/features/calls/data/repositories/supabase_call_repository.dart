import 'dart:async';

import 'package:salahly/core/async/single_flight.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/error/supabase_errors.dart';
import 'package:salahly/core/serialization/wire.dart';
import 'package:salahly/features/calls/data/models/call_models.dart';
import 'package:salahly/features/calls/domain/entities/call.dart';
import 'package:salahly/features/calls/domain/failures/call_failures.dart';
import 'package:salahly/features/calls/domain/repositories/call_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCallRepository implements CallRepository {
  SupabaseCallRepository(
    this._client, {
    this._pollEvery = const Duration(seconds: 3),
  });

  final SupabaseClient _client;

  /// Realtime tells of new rows at once; this catches up on any it missed.
  final Duration _pollEvery;

  static const _publicStun = [
    {'urls': 'stun:stun.l.google.com:19302'},
  ];

  @override
  Future<List<Map<String, dynamic>>> iceServers() async {
    try {
      final response = await _client.functions.invoke('call-ice-servers');
      final data = response.data;
      if (data is Map<String, dynamic> && data['iceServers'] is List) {
        final servers = [
          for (final item in data['iceServers'] as List<dynamic>)
            if (item is Map<String, dynamic>) item,
        ];
        if (servers.isNotEmpty) return servers;
      }
    } on Object {
      // Fall back to the public server.
    }
    return _publicStun;
  }

  @override
  Future<Result<String>> start(String requestId, String technicianId) =>
      _call(() async {
        final json = await _client.rpc<Map<String, dynamic>>(
          'start_call',
          params: {'p_request_id': requestId, 'p_technician_id': technicianId},
        );
        return json['id'] as String;
      });

  @override
  Future<Result<void>> answer(String callId) => _call(
    () => _client.rpc<void>('answer_call', params: {'p_call_id': callId}),
  );

  @override
  Future<Result<void>> end(String callId) =>
      _call(() => _client.rpc<void>('end_call', params: {'p_call_id': callId}));

  @override
  Future<Result<void>> sendSignal(String callId, CallSignalDraft signal) =>
      _call(
        () => _client.rpc<void>(
          'send_call_signal',
          params: {
            'p_call_id': callId,
            'p_kind': toWire(signal.kind),
            'p_payload': signal.payload,
          },
        ),
      );

  @override
  Future<Result<IncomingCall?>> pending() => _call(() async {
    final json = await _client.rpc<Map<String, dynamic>?>('pending_call');
    return json == null ? null : CallModels.incoming(json);
  });

  @override
  Stream<CallSignal> signals(String callId) {
    var lastId = 0;
    return _watch(
      channelName: 'call-signals:$callId',
      table: 'call_signals',
      event: PostgresChangeEvent.insert,
      column: 'call_id',
      value: callId,
      refresh: (sink) async {
        final result = await _call(() async {
          final json = await _client.rpc<List<dynamic>>(
            'call_signals_after',
            params: {'p_call_id': callId, 'p_after': lastId},
          );
          return [
            for (final item in json)
              CallModels.signal(item as Map<String, dynamic>),
          ];
        });
        if (result case Ok(:final value)) {
          for (final signal in value) {
            lastId = signal.id;
            sink.add(signal);
          }
        }
      },
    );
  }

  @override
  Stream<CallStatus> statuses(String callId) {
    CallStatus? last;
    return _watch(
      channelName: 'call-status:$callId',
      table: 'request_calls',
      event: PostgresChangeEvent.update,
      column: 'id',
      value: callId,
      refresh: (sink) async {
        final result = await _call(() async {
          final row = await _client
              .from('request_calls')
              .select('status')
              .eq('id', callId)
              .maybeSingle();
          return row == null
              ? null
              : enumFromWire(CallStatus.values, row['status']);
        });
        if (result case Ok(:final value?) when value != last) {
          last = value;
          sink.add(value);
        }
      },
    );
  }

  /// A stream fed by [refresh], which runs on opening, on each Realtime
  /// change and every poll, one at a time. The channel closes with the last
  /// listener.
  Stream<T> _watch<T>({
    required String channelName,
    required String table,
    required PostgresChangeEvent event,
    required String column,
    required String value,
    required Future<void> Function(StreamSink<T> sink) refresh,
  }) {
    RealtimeChannel? channel;
    Timer? poll;
    late final StreamController<T> stream;
    final flight = SingleFlight(() async {
      if (!stream.isClosed) await refresh(stream.sink);
    });
    stream = StreamController<T>(
      onListen: () {
        channel = _client
            .channel(channelName)
            .onPostgresChanges(
              event: event,
              schema: 'public',
              table: table,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: column,
                value: value,
              ),
              callback: (_) => unawaited(flight()),
            )
            .subscribe();
        poll = Timer.periodic(_pollEvery, (_) => unawaited(flight()));
        unawaited(flight());
      },
      onCancel: () async {
        poll?.cancel();
        if (channel case final open?) await _client.removeChannel(open);
        channel = null;
      },
    );
    return stream.stream;
  }

  static Future<Result<T>> _call<T>(Future<T> Function() action) async {
    try {
      return Ok(await action());
    } on Object catch (error) {
      return Err<T>(_failureFrom(error));
    }
  }

  static Failure _failureFrom(Object error) {
    if (error is PostgrestException) {
      switch (error.message) {
        case 'call_unavailable':
          return const CallUnavailableFailure();
        case 'call_in_progress':
          return const CallInProgressFailure();
        case 'callee_busy':
          return const CalleeBusyFailure();
        case 'rate_limited':
          return const RateLimitedFailure();
      }
    }
    return commonFailureFrom(error);
  }
}
