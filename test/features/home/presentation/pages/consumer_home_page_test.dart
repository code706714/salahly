import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/home/presentation/pages/consumer_home_page.dart';

import '../../../../pump_app.dart';

class _MockSessionCubit extends MockCubit<SessionState>
    implements SessionCubit {}

SessionReady signedInConsumer({required int requestCredits}) => SessionReady(
  user: const AuthUser(id: 'user-1'),
  profile: UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'منى أحمد',
    activeRole: UserRole.consumer,
    consumer: ConsumerProfile(
      honorific: Honorific.ms,
      areaName: 'مدينة نصر',
      requestCredits: requestCredits,
    ),
  ),
);

void main() {
  late SessionCubit session;

  setUpAll(loadAppFonts);

  setUp(() => session = _MockSessionCubit());

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const ConsumerHomePage(),
    blocs: [BlocProvider<SessionCubit>.value(value: session)],
  );

  group('ConsumerHomePage', () {
    testWidgets('greets the consumer by first name on a small phone', (
      tester,
    ) async {
      when(
        () => session.state,
      ).thenReturn(signedInConsumer(requestCredits: 2));

      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.greeting('منى')), findsOneWidget);
      expect(find.text('مدينة نصر'), findsOneWidget);
    });

    testWidgets('shows the free requests left', (tester) async {
      when(
        () => session.state,
      ).thenReturn(signedInConsumer(requestCredits: 2));

      await pumpPage(tester);

      expect(find.text(l10n.consumerCreditsLeft(2)), findsOneWidget);
    });

    testWidgets('says when the free requests are used up', (tester) async {
      when(
        () => session.state,
      ).thenReturn(signedInConsumer(requestCredits: 0));

      await pumpPage(tester);

      expect(find.text(l10n.consumerCreditsLeft(0)), findsOneWidget);
    });

    testWidgets('shows nothing while signing out', (tester) async {
      when(() => session.state).thenReturn(const SessionSignedOut());

      await pumpPage(tester);

      expect(find.textContaining(l10n.greeting('')), findsNothing);
    });
  });
}
