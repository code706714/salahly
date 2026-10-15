import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/onboarding/presentation/pages/role_choice_page.dart';

import '../../../../helpers/mocks.dart';
import '../../../../pump_app.dart';

void main() {
  setUpAll(loadAppFonts);

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const RoleChoicePage(),
    stubRoutes: [
      AppRoutes.consumerOnboarding,
      AppRoutes.technicianOnboarding,
    ],
  );

  group('RoleChoicePage', () {
    testWidgets('fits both roles on a small phone', (tester) async {
      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.welcomeTitle), findsOneWidget);
      expect(find.text(l10n.roleConsumerTitle), findsOneWidget);
      expect(find.text(l10n.roleTechnicianTitle), findsOneWidget);
      expect(find.text(l10n.trustBadge), findsOneWidget);
    });

    testWidgets('signs out for someone who came in with the wrong number', (
      tester,
    ) async {
      final session = MockSessionCubit();
      when(session.signOut).thenAnswer((_) async {});
      await tester.pumpApp(
        const RoleChoicePage(),
        blocs: [BlocProvider<SessionCubit>.value(value: session)],
      );

      await tester.ensureVisible(find.text(l10n.roleUseAnotherNumber));
      await tester.tap(find.text(l10n.roleUseAnotherNumber));

      verify(session.signOut).called(1);
    });

    testWidgets('opens consumer onboarding from the consumer card', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.roleConsumerTitle));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.consumerOnboarding), findsOneWidget);
    });

    testWidgets('opens technician onboarding from the technician card', (
      tester,
    ) async {
      await pumpPage(tester);

      await tester.tap(find.text(l10n.roleTechnicianBody));
      await tester.pumpAndSettle();

      expect(find.text(AppRoutes.technicianOnboarding), findsOneWidget);
    });
  });
}
