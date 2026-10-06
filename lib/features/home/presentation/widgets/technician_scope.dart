import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';

/// Wraps every technician screen: keeps the phone's records syncing while
/// the app is open, the area and category names at hand, and the new
/// requests from the platform fresh.
///
/// The free jobs left change when a consumer picks an offer, which this
/// phone can't see happen, so the profile is fetched again whenever the
/// app comes back.
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
  late final CategoriesCubit _categories = CategoriesCubit(context.read());
  late final IncomingRequestsCubit _requests = IncomingRequestsCubit(
    context.read(),
  );
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resume, onPause: _sync.pause);
    unawaited(_sync.start());
    _load();
  }

  void _resume() {
    _sync.resume();
    unawaited(context.read<SessionCubit>().refreshProfile());
    _load();
  }

  /// The catalog loads once; a load that failed offline is retried here.
  void _load() {
    unawaited(_areas.load());
    unawaited(_categories.load());
    unawaited(_requests.fetchNewRequests());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_sync.close());
    unawaited(_areas.close());
    unawaited(_categories.close());
    unawaited(_requests.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _sync),
        BlocProvider.value(value: _areas),
        BlocProvider.value(value: _categories),
        BlocProvider.value(value: _requests),
      ],
      child: BlocListener<SyncCubit, SyncState>(
        // What was missed while offline loads once the server answers
        // again, and new requests come with every sync.
        listenWhen: (previous, current) =>
            previous.lastSyncedAt != current.lastSyncedAt,
        listener: (context, state) => _load(),
        child: widget.child,
      ),
    );
  }
}
