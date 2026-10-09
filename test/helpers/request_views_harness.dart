import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/request_cubit.dart';

import '../pump_app.dart';
import 'fixtures.dart';
import 'mocks.dart';

class MockRequestCubit extends MockCubit<RequestState>
    implements RequestCubit {}

class MockCategoriesCubit extends MockCubit<CategoriesState>
    implements CategoriesCubit {}

/// Signed in as the consumer نورهان, addressed by [honorific].
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

/// What a consumer screen reads from above: the session, the catalog and,
/// for the request's own screens, the [request] cubit.
class ConsumerViewHarness {
  ConsumerViewHarness({Honorific honorific = Honorific.ms}) {
    when(() => session.state).thenReturn(consumerSession(honorific: honorific));
    when(
      () => categories.state,
    ).thenReturn(const CategoriesState(categories: TestCategories.all));
    when(() => areas.state).thenReturn(const AreasState(areas: TestAreas.all));
    when(() => request.acceptOffer(any())).thenAnswer((_) async => true);
    when(request.cancel).thenAnswer((_) async => true);
    when(request.widenWindow).thenAnswer((_) async => true);
  }

  final session = MockSessionCubit();
  final categories = MockCategoriesCubit();
  final areas = MockAreasCubit();
  final request = MockRequestCubit();

  /// Shows [details] with [busy] running.
  void show(RequestDetails details, {RequestAction? busy}) =>
      when(
        () => request.state,
      ).thenReturn(
        RequestState(
          status: RequestLoadStatus.ready,
          details: details,
          busy: busy,
        ),
      );

  Future<void> pump(
    WidgetTester tester,
    Widget view, {
    List<RepositoryProvider<Object>> repositories = const [],
    List<BlocProvider<StateStreamableSource<Object?>>> blocs = const [],
    List<String> stubRoutes = const [],
    Size surfaceSize = smallPhone,
  }) => tester.pumpApp(
    view,
    repositories: repositories,
    blocs: [
      BlocProvider<SessionCubit>.value(value: session),
      BlocProvider<CategoriesCubit>.value(value: categories),
      BlocProvider<AreasCubit>.value(value: areas),
      BlocProvider<RequestCubit>.value(value: request),
      ...blocs,
    ],
    stubRoutes: stubRoutes,
    surfaceSize: surfaceSize,
  );
}
