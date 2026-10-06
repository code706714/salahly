import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:salahly/core/contacts/contact_picker.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/database/local_user_data.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/location/geolocator_location_service.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/core/network/network_status.dart';
import 'package:salahly/core/speech/speech_input.dart';
import 'package:salahly/core/storage/json_file_cache.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/storage/shared_files.dart';
import 'package:salahly/core/storage/user_scoped_data.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/supabase_sync_remote.dart';
import 'package:salahly/core/sync/sync_engine.dart';
import 'package:salahly/features/account/data/datasources/account_local_data_source.dart';
import 'package:salahly/features/account/data/datasources/account_remote_data_source.dart';
import 'package:salahly/features/account/data/repositories/account_repository_impl.dart';
import 'package:salahly/features/account/domain/repositories/account_repository.dart';
import 'package:salahly/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/balance/data/repositories/supabase_balance_repository.dart';
import 'package:salahly/features/balance/domain/repositories/balance_repository.dart';
import 'package:salahly/features/catalog/data/repositories/supabase_catalog_repository.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:salahly/features/customers/data/repositories/drift_customers_repository.dart';
import 'package:salahly/features/customers/domain/repositories/customers_repository.dart';
import 'package:salahly/features/jobs/data/repositories/drift_jobs_repository.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';
import 'package:salahly/features/marketplace/data/repositories/supabase_consumer_requests_repository.dart';
import 'package:salahly/features/marketplace/data/repositories/supabase_technician_requests_repository.dart';
import 'package:salahly/features/marketplace/domain/repositories/consumer_requests_repository.dart';
import 'package:salahly/features/marketplace/domain/repositories/technician_requests_repository.dart';
import 'package:salahly/features/notifications/data/repositories/supabase_notifications_repository.dart';
import 'package:salahly/features/notifications/domain/repositories/notifications_repository.dart';
import 'package:salahly/features/onboarding/data/repositories/supabase_onboarding_repository.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Everything the app talks to outside itself, built once in `main` and
/// handed down the widget tree. Tests build it with fakes.
class AppDependencies {
  const AppDependencies({
    required this.authRepository,
    required this.accountRepository,
    required this.catalogRepository,
    required this.onboardingRepository,
    required this.customersRepository,
    required this.jobsRepository,
    required this.consumerRequestsRepository,
    required this.technicianRequestsRepository,
    required this.balanceRepository,
    required this.notificationsRepository,
    required this.locationService,
    required this.photoPicker,
    required this.userData,
    required this.networkStatus,
    required this.localChanges,
    required this.database,
    required this.syncEngine,
    required this.externalApps,
    required this.speechInput,
    required this.contactPicker,
    required this.sharedFiles,
  });

  factory AppDependencies.live({
    required SupabaseClient client,
    required FlutterSecureStorage storage,
    required Directory supportDirectory,
    required Directory cacheDirectory,
  }) {
    final authRepository = SupabaseAuthRepository(client.auth);
    final database = AppDatabase.open();
    final photos = LocalPhotoStore(
      Directory('${supportDirectory.path}/job_photos'),
    );
    final sharedFiles = SharedFiles(
      Directory('${cacheDirectory.path}/shared'),
    );
    final localChanges = LocalChanges();
    return AppDependencies(
      authRepository: authRepository,
      accountRepository: AccountRepositoryImpl(
        remote: AccountRemoteDataSource(client),
        local: AccountLocalDataSource(storage),
      ),
      catalogRepository: SupabaseCatalogRepository(
        client,
        areasCache: JsonFileCache(
          File('${supportDirectory.path}/catalog/areas.json'),
        ),
      ),
      onboardingRepository: SupabaseOnboardingRepository(client),
      customersRepository: DriftCustomersRepository(
        database: database,
        changes: localChanges,
      ),
      jobsRepository: DriftJobsRepository(
        database: database,
        photos: photos,
        changes: localChanges,
        currentUserId: () => authRepository.currentUser?.id,
      ),
      consumerRequestsRepository: SupabaseConsumerRequestsRepository(client),
      technicianRequestsRepository: SupabaseTechnicianRequestsRepository(
        client,
      ),
      balanceRepository: SupabaseBalanceRepository(client),
      notificationsRepository: SupabaseNotificationsRepository(client),
      locationService: const GeolocatorLocationService(),
      photoPicker: PhotoPicker(),
      userData: LocalUserData(database, photos, sharedFiles),
      networkStatus: ConnectivityNetworkStatus(),
      localChanges: localChanges,
      database: database,
      syncEngine: SyncEngine(
        database: database,
        remote: SupabaseSyncRemote(client),
        photos: photos,
      ),
      externalApps: const SystemExternalApps(),
      speechInput: DeviceSpeechInput(),
      contactPicker: ContactPicker(),
      sharedFiles: sharedFiles,
    );
  }

  final AuthRepository authRepository;
  final AccountRepository accountRepository;
  final CatalogRepository catalogRepository;
  final OnboardingRepository onboardingRepository;
  final CustomersRepository customersRepository;
  final JobsRepository jobsRepository;
  final ConsumerRequestsRepository consumerRequestsRepository;
  final TechnicianRequestsRepository technicianRequestsRepository;
  final BalanceRepository balanceRepository;
  final NotificationsRepository notificationsRepository;
  final LocationService locationService;
  final PhotoPicker photoPicker;
  final UserScopedData userData;
  final NetworkStatus networkStatus;
  final LocalChanges localChanges;
  final AppDatabase database;
  final SyncEngine syncEngine;
  final ExternalApps externalApps;
  final SpeechInput speechInput;
  final ContactPicker contactPicker;
  final SharedFiles sharedFiles;
}
