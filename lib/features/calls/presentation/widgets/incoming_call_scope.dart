import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/live/live_updates.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/calls/domain/repositories/call_repository.dart';

/// Opens the call screen when someone calls the person: as the server
/// reports the ring while the app is open, and when the app comes back from
/// the call's notice.
class IncomingCallScope extends StatefulWidget {
  const IncomingCallScope({required this.role, required this.child, super.key});

  final UserRole role;
  final Widget child;

  @override
  State<IncomingCallScope> createState() => _IncomingCallScopeState();
}

class _IncomingCallScopeState extends State<IncomingCallScope> {
  late final CallRepository _calls = context.read();
  late final StreamSubscription<void> _live;
  late final AppLifecycleListener _lifecycle;
  String? _shown;

  @override
  void initState() {
    super.initState();
    _live = context.read<LiveUpdates>().changes.listen((_) => _check());
    _lifecycle = AppLifecycleListener(onResume: _check);
    _check();
  }

  /// Opens each ringing call once.
  void _check() => unawaited(_open());

  Future<void> _open() async {
    final result = await _calls.pending();
    if (!mounted) return;
    if (result case Ok(:final value?) when value.id != _shown) {
      _shown = value.id;
      unawaited(
        context.push(
          AppRoutes.call(
            widget.role,
            requestId: value.requestId,
            technicianId: value.technicianId,
            name: value.callerName,
            callId: value.id,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_live.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
