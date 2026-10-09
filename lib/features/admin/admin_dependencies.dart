import 'package:salahly/features/admin/data/repositories/supabase_admin_files_repository.dart';
import 'package:salahly/features/admin/data/repositories/supabase_audit_repository.dart';
import 'package:salahly/features/admin/data/repositories/supabase_overview_repository.dart';
import 'package:salahly/features/admin/data/repositories/supabase_requests_repository.dart';
import 'package:salahly/features/admin/data/repositories/supabase_settings_repository.dart';
import 'package:salahly/features/admin/data/repositories/supabase_topup_review_repository.dart';
import 'package:salahly/features/admin/data/repositories/supabase_users_repository.dart';
import 'package:salahly/features/admin/data/repositories/supabase_verification_repository.dart';
import 'package:salahly/features/admin/domain/repositories/admin_files_repository.dart';
import 'package:salahly/features/admin/domain/repositories/audit_repository.dart';
import 'package:salahly/features/admin/domain/repositories/overview_repository.dart';
import 'package:salahly/features/admin/domain/repositories/requests_repository.dart';
import 'package:salahly/features/admin/domain/repositories/settings_repository.dart';
import 'package:salahly/features/admin/domain/repositories/topup_review_repository.dart';
import 'package:salahly/features/admin/domain/repositories/users_repository.dart';
import 'package:salahly/features/admin/domain/repositories/verification_repository.dart';
import 'package:salahly/features/auth/data/repositories/supabase_auth_repository.dart';
import 'package:salahly/features/auth/domain/repositories/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Everything the console talks to, built once. The console's entry point
/// builds the live set; a test builds it from fakes.
class AdminDependencies {
  const AdminDependencies({
    required this.authRepository,
    required this.overviewRepository,
    required this.verificationRepository,
    required this.topupReviewRepository,
    required this.requestsRepository,
    required this.usersRepository,
    required this.settingsRepository,
    required this.auditRepository,
    required this.filesRepository,
  });

  /// Every repository backed by [client]'s session. The admin's own session
  /// is the only credential: no service key is ever present in the console.
  factory AdminDependencies.live(SupabaseClient client) {
    return AdminDependencies(
      authRepository: SupabaseAuthRepository(client.auth),
      overviewRepository: SupabaseOverviewRepository(client),
      verificationRepository: SupabaseVerificationRepository(client),
      topupReviewRepository: SupabaseTopupReviewRepository(client),
      requestsRepository: SupabaseRequestsRepository(client),
      usersRepository: SupabaseUsersRepository(client),
      settingsRepository: SupabaseSettingsRepository(client),
      auditRepository: SupabaseAuditRepository(client),
      filesRepository: SupabaseAdminFilesRepository(client),
    );
  }

  final AuthRepository authRepository;
  final OverviewRepository overviewRepository;
  final VerificationRepository verificationRepository;
  final TopupReviewRepository topupReviewRepository;
  final RequestsRepository requestsRepository;
  final UsersRepository usersRepository;
  final SettingsRepository settingsRepository;
  final AuditRepository auditRepository;
  final AdminFilesRepository filesRepository;
}
