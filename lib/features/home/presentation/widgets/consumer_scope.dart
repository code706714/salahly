import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/notifications/presentation/cubit/notifications_cubit.dart';

/// Wraps every consumer screen: the area and category names, the
/// consumer's requests and how many notifications are unread, fetched
/// again whenever the app comes back.
///
/// The free requests left change with a request (sent, cancelled, expired),
/// so the profile is fetched again whenever the list changes; and with an
/// approved transfer, which this phone can't see happen, so it is fetched
/// again whenever the app comes back.
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
  late final NotificationsCubit _notifications = NotificationsCubit(
    notifications: context.read(),
    role: UserRole.consumer,
  );
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _resume);
    _load();
  }

  void _resume() {
    unawaited(context.read<SessionCubit>().refreshProfile());
    _load();
  }

  /// The catalog loads once; a load that failed offline is retried here.
  void _load() {
    unawaited(_areas.load());
    unawaited(_categories.load());
    unawaited(_requests.load());
    unawaited(_notifications.refreshUnread());
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_areas.close());
    unawaited(_categories.close());
    unawaited(_requests.close());
    unawaited(_notifications.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _areas),
        BlocProvider.value(value: _categories),
        BlocProvider.value(value: _requests),
        BlocProvider.value(value: _notifications),
      ],
      child: BlocListener<MyRequestsCubit, MyRequestsState>(
        listenWhen: (previous, current) =>
            previous.status == MyRequestsStatus.ready &&
            previous.requests != current.requests,
        listener: (context, state) {
          unawaited(context.read<SessionCubit>().refreshProfile());
          unawaited(_notifications.refreshUnread());
        },
        child: widget.child,
      ),
    );
  }
}
