import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/live/live_updates.dart';

/// Runs [onChange] each time the server reports something new for the
/// person, for as long as this widget is on screen.
class LiveRefresh extends StatefulWidget {
  const LiveRefresh({required this.onChange, required this.child, super.key});

  final VoidCallback onChange;
  final Widget child;

  @override
  State<LiveRefresh> createState() => _LiveRefreshState();
}

class _LiveRefreshState extends State<LiveRefresh> {
  late final StreamSubscription<void> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = context.read<LiveUpdates>().changes.listen(
      (_) => widget.onChange(),
    );
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
