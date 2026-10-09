import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A first screen that pushes [view] over itself, for testing a screen
/// that leaves by popping. Pump it with `pumpApp`, then `openPushedView`.
class PushedView extends StatelessWidget {
  const PushedView(this.view, {super.key});

  /// The first screen's only text, to check that [view] popped.
  static const launcher = 'launcher';

  final Widget view;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Navigator.of(
            context,
          ).push(MaterialPageRoute<void>(builder: (context) => view)),
          child: const Text(launcher),
        ),
      ),
    );
  }
}

extension OpenPushedView on WidgetTester {
  /// Opens the view of the [PushedView] pumped first.
  Future<void> openPushedView() async {
    await tap(find.text(PushedView.launcher));
    await pumpAndSettle();
  }
}
