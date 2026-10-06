import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/contacts/contact_picker.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/speech/speech_input.dart';
import 'package:salahly/core/storage/user_scoped_data.dart';
import 'package:salahly/core/sync/sync_cubit.dart';
import 'package:salahly/features/account/domain/repositories/account_repository.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/customers/domain/repositories/customers_repository.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

class MockCatalogRepository extends Mock implements CatalogRepository {}

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockLocationService extends Mock implements LocationService {}

class MockUserScopedData extends Mock implements UserScopedData {}

class MockJobsRepository extends Mock implements JobsRepository {}

class MockCustomersRepository extends Mock implements CustomersRepository {}

class MockExternalApps extends Mock implements ExternalApps {}

class MockSpeechInput extends Mock implements SpeechInput {}

class MockContactPicker extends Mock implements ContactPicker {}

class MockPhotoPicker extends Mock implements PhotoPicker {}

class MockSessionCubit extends MockCubit<SessionState>
    implements SessionCubit {}

class MockSyncCubit extends MockCubit<SyncState> implements SyncCubit {}

class MockAreasCubit extends MockCubit<AreasState> implements AreasCubit {}

class MockConsumerRequestsRepository extends Mock
    implements ConsumerRequestsRepository {}

class MockTechnicianRequestsRepository extends Mock
    implements TechnicianRequestsRepository {}
