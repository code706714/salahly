import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/time/clock_cubit.dart';

void main() {
  test('starts at the current time', () async {
    final cubit = ClockCubit(clock: () => DateTime(2026, 10, 6, 9));

    expect(cubit.state, DateTime(2026, 10, 6, 9));
    await cubit.close();
  });

  test('moves on every minute once started, and stops when closed', () {
    fakeAsync((async) {
      var now = DateTime(2026, 10, 6, 9);
      final cubit = ClockCubit(clock: () => now);
      final seen = <DateTime>[];
      final subscription = cubit.stream.listen(seen.add);

      now = DateTime(2026, 10, 6, 9, 1);
      async.elapse(const Duration(minutes: 1));
      expect(seen, isEmpty);

      cubit
        ..start()
        ..start();
      async.elapse(const Duration(minutes: 1));
      expect(seen, [DateTime(2026, 10, 6, 9, 1)]);

      now = DateTime(2026, 10, 6, 9, 2);
      async.elapse(const Duration(minutes: 1));
      expect(seen, [DateTime(2026, 10, 6, 9, 1), DateTime(2026, 10, 6, 9, 2)]);

      unawaited(cubit.close());
      async
        ..elapse(const Duration(minutes: 5))
        ..flushMicrotasks();
      expect(seen, hasLength(2));
      unawaited(subscription.cancel());
    });
  });
}
