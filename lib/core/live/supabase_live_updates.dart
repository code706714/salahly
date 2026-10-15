import 'dart:async';

import 'package:salahly/core/live/live_updates.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Listens to the person's own rows in `notifications` over Supabase
/// Realtime. Row level security keeps every other person's rows out of the
/// stream. One channel is shared by every listener (two joins of the same
/// topic would close each other) and closes with the last of them.
class SupabaseLiveUpdates implements LiveUpdates {
  SupabaseLiveUpdates(this._client);

  final SupabaseClient _client;

  late final Stream<void> _shared = _open();

  @override
  Stream<void> get changes => _shared;

  Stream<void> _open() {
    RealtimeChannel? channel;
    late final StreamController<void> controller;
    controller = StreamController<void>.broadcast(
      onListen: () {
        final userId = _client.auth.currentUser?.id;
        if (userId == null) return;
        channel = _client
            .channel('notifications:$userId')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'notifications',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'user_id',
                value: userId,
              ),
              callback: (_) => controller.add(null),
            )
            .subscribe();
      },
      onCancel: () async {
        if (channel case final open?) await _client.removeChannel(open);
        channel = null;
      },
    );
    return controller.stream;
  }
}
