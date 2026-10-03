import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';

/// Wraps every consumer screen: the area and category names, and the
/// consumer's requests, fetched again whenever the app comes back.
///
/// The free requests left change only with a request (sent, cancelled,
/// expired), so the profile is fetched again whenever the list changes.
class ConsumerScope extends StatefulWidget {
  const ConsumerScope({required this.child, super.key});

  final Widget child;

  @override
  State<ConsumerScope> createState() => _ConsumerScopeState();
}

class _ConsumerScopeState extends State<ConsumerScope> {
  late final AreasCubit _areas = AreasCubit(context.read());
  late final CategoriesCubit _categories = CategoriesCubit(context.read());
  late final MyRequestsCubit _requests = MyRequestsCubit(context.read());
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _load);
    _load();
  }

  /// The catalog loads once; a load that failed offline is retried here.
  void _load() {
    unawaited(_areas.load());
    unawaited(_categories.load());
    unawaited(_requests.load());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_areas.close());
    unawaited(_categories.close());
    unawaited(_requests.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _areas),
        BlocProvider.value(value: _categories),
        BlocProvider.value(value: _requests),
      ],
      child: BlocListener<MyRequestsCubit, MyRequestsState>(
        listenWhen: (previous, current) =>
            previous.status == MyRequestsStatus.ready &&
            previous.requests != current.requests,
        listener: (context, state) =>
            unawaited(context.read<SessionCubit>().refreshProfile()),
        child: widget.child,
      ),
    );
  }
}
