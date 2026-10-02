import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/home/presentation/pages/technician_home_page.dart';

import '../../../../pump_app.dart';

class _MockSessionCubit extends MockCubit<SessionState>
    implements SessionCubit {}

SessionReady signedInTechnician(VerificationStatus status) => SessionReady(
  user: const AuthUser(id: 'user-1'),
  profile: UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'محمد السيد',
    activeRole: UserRole.technician,
    technician: TechnicianProfile(verificationStatus: status, jobCredits: 3),
  ),
);

void main() {
  late SessionCubit session;

  setUpAll(loadAppFonts);

  setUp(() => session = _MockSessionCubit());

  Future<void> pumpPage(WidgetTester tester) => tester.pumpApp(
    const TechnicianHomePage(),
    blocs: [BlocProvider<SessionCubit>.value(value: session)],
  );

  group('TechnicianHomePage', () {
    testWidgets('greets the technician by first name on a small phone', (
      tester,
    ) async {
      when(
        () => session.state,
      ).thenReturn(signedInTechnician(VerificationStatus.approved));

      await pumpPage(tester);

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.greeting('محمد')), findsOneWidget);
    });

    testWidgets('says the ID is being reviewed while pending', (tester) async {
      when(
        () => session.state,
      ).thenReturn(signedInTechnician(VerificationStatus.pending));

      await pumpPage(tester);

      expect(
        find.textContaining(l10n.techPendingTitle, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('asks for new photos when rejected', (tester) async {
      when(
        () => session.state,
      ).thenReturn(signedInTechnician(VerificationStatus.rejected));

      await pumpPage(tester);

      expect(
        find.textContaining(l10n.techRejectedTitle, findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('shows no verification banner once approved', (tester) async {
      when(
        () => session.state,
      ).thenReturn(signedInTechnician(VerificationStatus.approved));

      await pumpPage(tester);

      expect(
        find.textContaining(l10n.techPendingTitle, findRichText: true),
        findsNothing,
      );
      expect(
        find.textContaining(l10n.techRejectedTitle, findRichText: true),
        findsNothing,
      );
    });

    testWidgets('shows nothing while signing out', (tester) async {
      when(() => session.state).thenReturn(const SessionSignedOut());

      await pumpPage(tester);

      expect(find.textContaining(l10n.greeting('')), findsNothing);
    });
  });
}
