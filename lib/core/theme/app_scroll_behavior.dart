import 'package:flutter/material.dart';

/// Every list scrolls the same way on every phone: it stops at its ends
/// without the Android stretch or glow, and can always be pulled down to
/// refresh, even when its content is shorter than the screen.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics());
}
