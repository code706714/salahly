import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/home/presentation/cubit/consumer_home_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/request_draft.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/addresses_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/my_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/new_request_cubit.dart';

import 'fixtures.dart';
import 'mocks.dart';

// Mocks and builders for the consumer's home, request form, account,
// addresses and past technicians screens.

class MockConsumerHomeCubit extends MockCubit<ConsumerHomeState>
    implements ConsumerHomeCubit {}

class MockNewRequestCubit extends MockCubit<NewRequestState>
    implements NewRequestCubit {}

class MockAddressesCubit extends MockCubit<AddressesState>
    implements AddressesCubit {}

class MockMyRequestsCubit extends MockCubit<MyRequestsState>
    implements MyRequestsCubit {}

class MockCategoriesCubit extends MockCubit<CategoriesState>
    implements CategoriesCubit {}

/// Call once from `setUpAll` before stubbing these screens' calls with
/// `any()`.
void registerConsumerScreenFallbacks() {
  registerFallbackValue(
    RequestDraft(
      categoryId: 'ac',
      issue: RequestIssue.other,
      addressId: 'address-1',
      day: DateTime(2026),
      window: RequestWindow.morning,
    ),
  );
  registerFallbackValue(
    const ConsumerAddressDraft(label: '', areaId: '', details: ''),
  );
  registerFallbackValue(PhotoSource.camera);
  registerFallbackValue(PhotoPurpose.request);
}

/// A signed-in consumer, a woman unless [honorific] says otherwise.
SessionReady testConsumerSession({
  Honorific honorific = Honorific.ms,
  int requestCredits = 1,
  String fullName = 'نورهان محمد',
}) => SessionReady(
  user: const AuthUser(id: 'consumer-1'),
  profile: UserProfile(
    id: 'consumer-1',
    phone: '+201114567720',
    fullName: fullName,
    activeRole: UserRole.consumer,
    consumer: ConsumerProfile(
      honorific: honorific,
      areaId: 'nasr_city',
      areaName: 'مدينة نصر',
      requestCredits: requestCredits,
    ),
  ),
);

/// The cubits ConsumerScope provides above every consumer screen, as
/// mocks: a signed-in woman, the test catalog and areas, and [requests].
class ConsumerScreenBlocs {
  ConsumerScreenBlocs({
    SessionState? session,
    List<RequestSummary> requests = const [],
    MyRequestsStatus status = MyRequestsStatus.ready,
  }) {
    when(() => this.session.state).thenReturn(session ?? testConsumerSession());
    when(
      () => categories.state,
    ).thenReturn(const CategoriesState(categories: TestCategories.all));
    when(categories.load).thenAnswer((_) async {});
    when(() => areas.state).thenReturn(const AreasState(areas: TestAreas.all));
    when(areas.load).thenAnswer((_) async {});
    when(
      () => myRequests.state,
    ).thenReturn(MyRequestsState(status: status, requests: requests));
    when(myRequests.load).thenAnswer((_) async {});
  }

  final session = MockSessionCubit();
  final categories = MockCategoriesCubit();
  final areas = MockAreasCubit();
  final myRequests = MockMyRequestsCubit();

  List<BlocProvider<StateStreamableSource<Object?>>> get providers => [
    BlocProvider<SessionCubit>.value(value: session),
    BlocProvider<CategoriesCubit>.value(value: categories),
    BlocProvider<AreasCubit>.value(value: areas),
    BlocProvider<MyRequestsCubit>.value(value: myRequests),
  ];
}
