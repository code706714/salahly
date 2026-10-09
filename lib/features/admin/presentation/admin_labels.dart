import 'package:intl/intl.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/failure_message.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/widgets/status_pill.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// What an admin screen says about [failure].
String adminFailureMessage(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      AdminRequiredFailure() => l10n.adminErrorForbidden,
      NotPendingFailure() => l10n.adminErrorNotPending,
      AdminNotFoundFailure() => l10n.adminErrorNotFound,
      InvalidInputFailure() => l10n.adminErrorInvalid,
      DuplicateFailure() => l10n.adminErrorDuplicate,
      LastActiveFailure() => l10n.adminErrorLastActive,
      CannotSuspendAdminFailure() => l10n.adminErrorCannotSuspendAdmin,
      RecentLoginRequiredFailure() => l10n.adminErrorRecentLogin,
      _ => commonFailureMessage(l10n, failure),
    };

/// How long ago [time] was: "دلوقتي", "من 40 دقيقة", "من ساعتين",
/// "امبارح", "من 3 أيام".
String adminAgeLabel(
  AppLocalizations l10n,
  DateTime time, {
  required DateTime now,
}) {
  // The device's clock may run behind the server's.
  final elapsed = now.isBefore(time) ? Duration.zero : now.difference(time);
  return switch (elapsed) {
    Duration(inMinutes: < 1) => l10n.adminAgeNow,
    Duration(inMinutes: < 60) => l10n.adminAgeMinutes(elapsed.inMinutes),
    Duration(inHours: < 24) => l10n.adminAgeHours(elapsed.inHours),
    Duration(inDays: < 7) => l10n.techProfileAgoDays(elapsed.inDays),
    Duration(inDays: < 30) => l10n.techProfileAgoWeeks(elapsed.inDays ~/ 7),
    Duration(inDays: < 365) => l10n.techProfileAgoMonths(elapsed.inDays ~/ 30),
    _ => l10n.techProfileAgoYears(elapsed.inDays ~/ 365),
  };
}

/// A date and time for the audit log: "7 أكتوبر 2026 · 3:05 م".
String adminDateTimeLabel(DateTime time) =>
    DateFormat('d MMMM y · h:mm a', 'ar').format(time);

/// A phone the way people write it, "0100 234 5678", or as it came when it
/// is not an Egyptian mobile.
String adminPhoneLabel(String phone) =>
    PhoneNumber.tryParse(phone)?.local ?? phone;

String overviewPeriodLabel(AppLocalizations l10n, OverviewPeriod period) =>
    switch (period) {
      OverviewPeriod.today => l10n.adminPeriodToday,
      OverviewPeriod.week => l10n.adminPeriodWeek,
      OverviewPeriod.month => l10n.adminPeriodMonth,
    };

String verificationStatusLabel(
  AppLocalizations l10n,
  VerificationStatus status,
) => switch (status) {
  VerificationStatus.pending => l10n.adminVerifyStatusPending,
  VerificationStatus.approved => l10n.adminVerifyStatusApproved,
  VerificationStatus.rejected => l10n.adminVerifyStatusRejected,
};

PillTone verificationStatusTone(VerificationStatus status) => switch (status) {
  VerificationStatus.pending => PillTone.waiting,
  VerificationStatus.approved => PillTone.success,
  VerificationStatus.rejected => PillTone.danger,
};

String adminTopupStatusLabel(AppLocalizations l10n, TopupStatus status) =>
    switch (status) {
      TopupStatus.pending => l10n.adminTopupsStatusPending,
      TopupStatus.approved => l10n.adminTopupsStatusApproved,
      TopupStatus.rejected => l10n.adminTopupsStatusRejected,
    };

String roleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
  UserRole.technician => l10n.adminRolePillTechnician,
  UserRole.consumer => l10n.adminRolePillConsumer,
};

/// What a pack holds: "10 شغلانات" for a technician, "5 طلبات" for a
/// customer.
String adminPackLabel(AppLocalizations l10n, UserRole role, int uses) =>
    switch (role) {
      UserRole.consumer => l10n.adminTopupsPackConsumer(uses),
      UserRole.technician => l10n.adminTopupsPackTechnician(uses),
    };

String adminRequestStatusLabel(
  AppLocalizations l10n,
  AdminRequestStatus status, {
  int? stars,
}) => switch (status) {
  AdminRequestStatus.noOffers => l10n.adminRequestsStatusNoOffers,
  AdminRequestStatus.awaitingChoice => l10n.adminRequestsStatusAwaiting,
  AdminRequestStatus.inProgress => l10n.adminRequestsStatusInProgress,
  AdminRequestStatus.done =>
    stars == null
        ? l10n.adminRequestsStatusDone
        : l10n.adminRequestsStatusDoneStars(stars),
  AdminRequestStatus.cancelled => l10n.adminRequestsStatusCancelled,
  AdminRequestStatus.expired => l10n.adminRequestsStatusExpired,
};

PillTone adminRequestStatusTone(AdminRequestStatus status) => switch (status) {
  AdminRequestStatus.noOffers => PillTone.danger,
  AdminRequestStatus.awaitingChoice => PillTone.waiting,
  AdminRequestStatus.inProgress => PillTone.attention,
  AdminRequestStatus.done => PillTone.success,
  AdminRequestStatus.cancelled ||
  AdminRequestStatus.expired => PillTone.neutral,
};

String adminComplaintReasonLabel(
  AppLocalizations l10n,
  ComplaintReason reason,
) => switch (reason) {
  ComplaintReason.noShowOrLate => l10n.adminComplaintReasonNoShow,
  ComplaintReason.priceRaised => l10n.adminComplaintReasonPriceRaised,
  ComplaintReason.poorWork => l10n.adminComplaintReasonPoorWork,
  ComplaintReason.badConduct => l10n.adminComplaintReasonBadConduct,
  ComplaintReason.other => l10n.adminComplaintReasonOther,
};

String accountStatusLabel(AppLocalizations l10n, AccountStatus status) =>
    switch (status) {
      AccountStatus.verified => l10n.adminUsersStatusVerified,
      AccountStatus.pending => l10n.adminUsersStatusPending,
      AccountStatus.rejected => l10n.adminUsersStatusRejected,
      AccountStatus.active => l10n.adminUsersStatusActive,
      AccountStatus.suspended => l10n.adminUsersStatusSuspended,
    };

PillTone accountStatusTone(AccountStatus status) => switch (status) {
  AccountStatus.verified || AccountStatus.active => PillTone.success,
  AccountStatus.pending => PillTone.waiting,
  AccountStatus.rejected || AccountStatus.suspended => PillTone.danger,
};

/// The name of an action in the audit log. An action this version does not
/// know is shown as the server names it.
String auditActionLabel(AppLocalizations l10n, String action) =>
    switch (action) {
      'view_verification' => l10n.adminAuditViewVerification,
      'approve_verification' => l10n.adminAuditApproveVerification,
      'reject_verification' => l10n.adminAuditRejectVerification,
      'approve_topup' => l10n.adminAuditApproveTopup,
      'reject_topup' => l10n.adminAuditRejectTopup,
      'resolve_complaint' => l10n.adminAuditResolveComplaint,
      'suspend_user' => l10n.adminAuditSuspendUser,
      'restore_user' => l10n.adminAuditRestoreUser,
      'update_settings' => l10n.adminAuditUpdateSettings,
      'create_credit_pack' => l10n.adminAuditCreatePack,
      'update_credit_pack' => l10n.adminAuditUpdatePack,
      'update_payment_account' => l10n.adminAuditUpdatePaymentAccount,
      'create_area' => l10n.adminAuditCreateArea,
      'update_area' => l10n.adminAuditUpdateArea,
      'set_area_open' => l10n.adminAuditSetAreaOpen,
      _ => action,
    };
