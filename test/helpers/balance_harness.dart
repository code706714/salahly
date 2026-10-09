import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/balance/presentation/cubit/balance_cubit.dart';
import 'package:salahly/features/balance/presentation/cubit/buy_uses_cubit.dart';

import '../pump_app.dart';
import 'follow_up_harness.dart';
import 'mocks.dart';

// Pumps the balance screens with mock cubits.

class MockBuyUsesCubit extends MockCubit<BuyUsesState>
    implements BuyUsesCubit {}

class MockBalanceCubit extends MockCubit<BalanceState>
    implements BalanceCubit {}

/// A signed-in technician named "محمود عبد الله" with [credits] jobs left.
SessionReady technicianSession({int credits = 2}) => SessionReady(
  user: const AuthUser(id: 'user-1'),
  profile: UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'محمود عبد الله',
    activeRole: UserRole.technician,
    technician: TechnicianProfile(
      verificationStatus: VerificationStatus.approved,
      jobCredits: credits,
    ),
  ),
);

/// A signed-in consumer with [credits] requests left.
SessionReady consumerWithCredits({
  Honorific honorific = Honorific.ms,
  int credits = 2,
}) => SessionReady(
  user: const AuthUser(id: 'consumer-1'),
  profile: UserProfile(
    id: 'consumer-1',
    phone: '+201114567720',
    fullName: 'نورهان محمد',
    activeRole: UserRole.consumer,
    consumer: ConsumerProfile(
      honorific: honorific,
      areaId: 'nasr_city',
      areaName: 'مدينة نصر',
      requestCredits: credits,
    ),
  ),
);

/// The cubits and edges around a balance screen; stub what a test needs
/// before [pump].
class BalanceHarness {
  BalanceHarness({required SessionReady session}) {
    when(() => this.session.state).thenReturn(session);
    when(() => this.session.refreshProfile()).thenAnswer((_) async {});
    when(buyUses.load).thenAnswer((_) async {});
    when(buyUses.submit).thenAnswer((_) async {});
    when(balance.load).thenAnswer((_) async {});
    when(
      () => photoPicker.pick(
        source: any(named: 'source'),
        purpose: any(named: 'purpose'),
      ),
    ).thenAnswer((_) async => '/tmp/proof.jpg');
  }

  /// Call once from `setUpAll` before using [BalanceHarness].
  static void registerFallbacks() {
    FollowUpHarness.registerFallbacks();
    registerFallbackValue(PhotoSource.camera);
    registerFallbackValue(PhotoPurpose.transfer);
  }

  final session = MockSessionCubit();
  final buyUses = MockBuyUsesCubit();
  final balance = MockBalanceCubit();
  final photoPicker = MockPhotoPicker();

  /// Pumps [view] on a small phone under the cubits a balance screen
  /// reads.
  Future<void> pump(
    WidgetTester tester,
    Widget view, {
    List<String> stubRoutes = const [],
    Size surfaceSize = smallPhone,
  }) async {
    when(() => buyUses.isClosed).thenReturn(false);
    when(() => balance.isClosed).thenReturn(false);
    await tester.pumpApp(
      view,
      repositories: [RepositoryProvider<PhotoPicker>.value(value: photoPicker)],
      blocs: [
        BlocProvider<SessionCubit>.value(value: session),
        BlocProvider<BuyUsesCubit>.value(value: buyUses),
        BlocProvider<BalanceCubit>.value(value: balance),
      ],
      stubRoutes: stubRoutes,
      surfaceSize: surfaceSize,
    );
    await tester.pump();
  }
}
