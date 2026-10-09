import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/consumer_app.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    ConsumerApp.registerFallbacks();
  });

  testConsumerApp('fetches the profile again on coming back', (
    tester,
    app,
  ) async {
    await app.pump(tester);
    clearInteractions(app.account);

    const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ].forEach(tester.binding.handleAppLifecycleStateChanged);
    await app.settle(tester);

    // The uses left grow when a transfer is approved meanwhile.
    verify(() => app.account.fetchProfile(any())).called(greaterThan(0));
  });
}
