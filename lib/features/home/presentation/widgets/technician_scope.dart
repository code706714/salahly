import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';

/// Wraps every technician screen: keeps the phone's records syncing while
/// the app is open and the area names at hand.
class TechnicianScope extends StatefulWidget {
  const TechnicianScope({required this.child, super.key});

  final Widget child;

  @override
  State<TechnicianScope> createState() => _TechnicianScopeState();
}

class _TechnicianScopeState extends State<TechnicianScope> {
  late final SyncCubit _sync = SyncCubit(
    engine: context.read(),
    database: context.read(),
    network: context.read(),
    changes: context.read(),
  );
  late final AreasCubit _areas = AreasCubit(context.read());
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: _sync.resume,
      onPause: _sync.pause,
    );
    unawaited(_sync.start());
    unawaited(_areas.load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_sync.close());
    unawaited(_areas.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _sync),
        BlocProvider.value(value: _areas),
      ],
      child: BlocListener<SyncCubit, SyncState>(
        // Areas missed while offline load once the server answers again.
        listenWhen: (previous, current) =>
            previous.lastSyncedAt != current.lastSyncedAt,
        listener: (context, state) => unawaited(_areas.load()),
        child: widget.child,
      ),
    );
  }
}
