import 'package:mocktail/mocktail.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/domain/repositories/audit_repository.dart';
import 'package:salahly/features/admin/domain/repositories/escrow_review_repository.dart';
import 'package:salahly/features/admin/domain/repositories/overview_repository.dart';
import 'package:salahly/features/admin/domain/repositories/requests_repository.dart';
import 'package:salahly/features/admin/domain/repositories/settings_repository.dart';
import 'package:salahly/features/admin/domain/repositories/topup_review_repository.dart';
import 'package:salahly/features/admin/domain/repositories/users_repository.dart';
import 'package:salahly/features/admin/domain/repositories/verification_repository.dart';
import 'package:salahly/features/admin/domain/repositories/withdrawal_review_repository.dart';

class MockOverviewRepository extends Mock implements OverviewRepository {}

class MockVerificationRepository extends Mock
    implements VerificationRepository {}

class MockTopupReviewRepository extends Mock implements TopupReviewRepository {}

class MockEscrowReviewRepository extends Mock
    implements EscrowReviewRepository {}

class MockWithdrawalReviewRepository extends Mock
    implements WithdrawalReviewRepository {}

class MockRequestsRepository extends Mock implements RequestsRepository {}

class MockUsersRepository extends Mock implements UsersRepository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockAuditRepository extends Mock implements AuditRepository {}

class MockAdminFilesRepository extends Mock implements AdminFilesRepository {}
