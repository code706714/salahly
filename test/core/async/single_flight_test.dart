import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/async/single_flight.dart';

void main() {
  test('a call during a run waits for one more run after it', () async {
    var runs = 0;
    var gate = Completer<void>();
    final fetch = SingleFlight(() async {
      runs++;
      await gate.future;
    });

    final first = fetch();
    final second = fetch();
    final third = fetch();
    expect(runs, 1);

    var secondDone = false;
    unawaited(second.then((_) => secondDone = true));
    gate.complete();
    gate = Completer<void>()..complete();
    await first;
    await third;

    expect(runs, 2);
    expect(secondDone, isTrue);
  });

  test('runs again on a later call, and after a failed run', () async {
    var runs = 0;
    final fetch = SingleFlight(() async {
      runs++;
      if (runs == 1) throw StateError('offline');
    });

    await expectLater(fetch(), throwsStateError);
    await fetch();

    expect(runs, 2);
  });
}
