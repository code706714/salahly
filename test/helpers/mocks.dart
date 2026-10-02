import 'package:mocktail/mocktail.dart';
import 'package:salahly/core/location/location_service.dart';
import 'package:salahly/features/account/domain/repositories/account_repository.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:salahly/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:salahly/features/onboarding/domain/repositories/onboarding_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAccountRepository extends Mock implements AccountRepository {}

class MockCatalogRepository extends Mock implements CatalogRepository {}

class MockOnboardingRepository extends Mock implements OnboardingRepository {}

class MockLocationService extends Mock implements LocationService {}
