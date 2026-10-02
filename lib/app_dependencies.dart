import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:salahly/core/location/geolocator_location_service.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/core/media/photo_picker.dart';
import 'package:salahly/features/account/data/datasources/account_local_data_source.dart';
import 'package:salahly/features/account/data/datasources/account_remote_data_source.dart';
import 'package:salahly/features/account/data/repositories/account_repository_impl.dart';
import 'package:salahly/features/account/domain/repositories/account_repository.dart';
import 'package:salahly/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/catalog/data/repositories/supabase_catalog_repository.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';
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
    required this.locationService,
    required this.photoPicker,
  });

  factory AppDependencies.live({
    required SupabaseClient client,
    required FlutterSecureStorage storage,
  }) {
    return AppDependencies(
      authRepository: SupabaseAuthRepository(client.auth),
      accountRepository: AccountRepositoryImpl(
        remote: AccountRemoteDataSource(client),
        local: AccountLocalDataSource(storage),
      ),
      catalogRepository: SupabaseCatalogRepository(client),
      onboardingRepository: SupabaseOnboardingRepository(client),
      locationService: const GeolocatorLocationService(),
      photoPicker: PhotoPicker(),
    );
  }

  final AuthRepository authRepository;
  final AccountRepository accountRepository;
  final CatalogRepository catalogRepository;
  final OnboardingRepository onboardingRepository;
  final LocationService locationService;
  final PhotoPicker photoPicker;
}
