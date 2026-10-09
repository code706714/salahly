import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/widgets/pull_to_refresh.dart';

void main() {
  testWidgets('pulling the list down fetches it again', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PullToRefresh(
          onRefresh: () async => refreshed++,
          child: ListView(
            children: const [SizedBox(height: 1000, child: Text('list'))],
          ),
        ),
      ),
    );

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(refreshed, 1);
  });

  testWidgets('does not fetch while the list is just scrolled', (tester) async {
    var refreshed = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: PullToRefresh(
          onRefresh: () async => refreshed++,
          child: ListView(
            children: const [SizedBox(height: 3000, child: Text('list'))],
          ),
        ),
      ),
    );

    await tester.fling(find.byType(ListView), const Offset(0, -400), 1000);
    await tester.pumpAndSettle();

    expect(refreshed, 0);
  });
}
