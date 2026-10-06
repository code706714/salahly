import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/complaint_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';

import '../pump_app.dart';
import 'fixtures.dart';
import 'mocks.dart';
import 'technician_app.dart';

// Pumps the consumer's follow-up screens (tracking, a new price, the
// invoice and rating, complaints and "طلباتي") with mock cubits.

class MockRequestCubit extends MockCubit<RequestState>
    implements RequestCubit {}

class MockMyRequestsCubit extends MockCubit<MyRequestsState>
    implements MyRequestsCubit {}

class MockComplaintCubit extends MockCubit<ComplaintState>
    implements ComplaintCubit {}

class MockCategoriesCubit extends MockCubit<CategoriesState>
    implements CategoriesCubit {}

/// A signed-in consumer named "نورهان محمد".
SessionReady consumerSession({Honorific honorific = Honorific.ms}) =>
    SessionReady(
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
          requestCredits: 2,
        ),
      ),
    );

/// The edges and cubits around a follow-up screen; stub what a test needs
/// before [pump].
class FollowUpHarness {
  FollowUpHarness({Honorific honorific = Honorific.ms}) {
    when(() => session.state).thenReturn(consumerSession(honorific: honorific));
    when(
      () => categories.state,
    ).thenReturn(const CategoriesState(categories: TestCategories.all));
    when(
      () => apps.whatsApp(
        text: any(named: 'text'),
        to: any(named: 'to'),
      ),
    ).thenAnswer((_) async => true);
    when(() => apps.dial(any())).thenAnswer((_) async => true);
    when(request.refresh).thenAnswer((_) async {});
    when(requests.load).thenAnswer((_) async {});
  }

  /// Call once from `setUpAll` before using [FollowUpHarness].
  static void registerFallbacks() => TechnicianApp.registerFallbacks();

  final session = MockSessionCubit();
  final categories = MockCategoriesCubit();
  final request = MockRequestCubit();
  final requests = MockMyRequestsCubit();
  final complaint = MockComplaintCubit();
  final apps = MockExternalApps();
  final photoPicker = MockPhotoPicker();

  /// Pumps [view] on a small phone under every cubit a follow-up screen
  /// reads.
  Future<void> pump(
    WidgetTester tester,
    Widget view, {
    List<String> stubRoutes = const [],
    Size surfaceSize = smallPhone,
  }) async {
    await tester.pumpApp(
      view,
      repositories: [
        RepositoryProvider<ExternalApps>.value(value: apps),
        RepositoryProvider<PhotoPicker>.value(value: photoPicker),
      ],
      blocs: [
        BlocProvider<SessionCubit>.value(value: session),
        BlocProvider<CategoriesCubit>.value(value: categories),
        BlocProvider<RequestCubit>.value(value: request),
        BlocProvider<MyRequestsCubit>.value(value: requests),
        BlocProvider<ComplaintCubit>.value(value: complaint),
      ],
      stubRoutes: stubRoutes,
      surfaceSize: surfaceSize,
    );
    await tester.pump();
  }
}

/// Scrolls the screen's list until [finder] is built and on screen.
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isNotEmpty) {
    await tester.ensureVisible(finder.first);
  } else {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  // Not settling: a busy spinner never stops.
  await tester.pump();
}
