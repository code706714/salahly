import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/home/presentation/pages/today_page.dart';
import 'package:salahly/features/jobs/presentation/pages/jobs_page.dart';

import '../../../../helpers/technician_app.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    TechnicianApp.registerFallbacks();
  });

  testTechnicianApp('syncs on opening and again on coming back', (
    tester,
    app,
  ) async {
    await app.pump(tester);
    final pullsOnOpen = app.remote.pulls.length;
    expect(pullsOnOpen, greaterThan(0));

    // The states a phone goes through to the background and back.
    void move(List<AppLifecycleState> states) =>
        states.forEach(tester.binding.handleAppLifecycleStateChanged);

    move(const [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
    ]);
    await app.settle(tester);
    expect(app.remote.pulls, hasLength(pullsOnOpen));

    move(const [
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    await app.settle(tester);
    expect(app.remote.pulls.length, greaterThan(pullsOnOpen));
  });

  testTechnicianApp('loads the area names for every screen', (
    tester,
    app,
  ) async {
    await app.pump(tester);

    final areas = tester
        .element(find.byType(TodayPage))
        .read<AreasCubit>()
        .state;
    expect(areas.nameOf('heliopolis'), 'مصر الجديدة');
    verify(app.catalog.fetchAreas).called(1);
  });

  testTechnicianApp('tapping the open tab again goes back to its start', (
    tester,
    app,
  ) async {
    await app.pump(tester);
    await tester.tap(find.text(l10n.navJobs).last);
    await app.settle(tester);
    expect(find.byType(JobsPage), findsOneWidget);

    await tester.tap(find.text(l10n.navToday).last);
    await app.settle(tester);
    await tester.tap(find.text(l10n.navToday).last);
    await app.settle(tester);

    expect(find.byType(TodayPage), findsOneWidget);
  });
}
