import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/admin_overview.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/domain/entities/admin_user.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/domain/entities/audit_entry.dart';
import 'package:salahly/features/admin/domain/entities/topup_review.dart';
import 'package:salahly/features/admin/domain/entities/verification.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';
import 'package:salahly/features/marketplace/domain/entities/complaint.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';

/// The time the fixtures are "now" for: ages in the pages count from it.
final adminNow = DateTime(2026, 10, 7, 12);

AdminOverview testOverview({
  OverviewPeriod period = OverviewPeriod.week,
  int verified = 76,
  int pendingVerifications = 12,
  int unanswered = 9,
  int openComplaints = 3,
  int pendingTopups = 7,
  List<LowRatedTechnician> lowRated = const [
    LowRatedTechnician(
      id: 'tech-low',
      name: 'كريم فوزي',
      rating: 3.3,
      reviewCount: 14,
    ),
  ],
}) {
  return AdminOverview(
    period: period,
    verifiedTechnicians: verified,
    verifiedTechnicianTarget: 100,
    requests: const RequestVolume(count: 142, previousCount: 124),
    funnel: const RequestFunnel(
      sent: 142,
      withOffer: 133,
      chosen: 104,
      finished: 91,
    ),
    rating: const RatingSummary(average: 4.6, count: 91),
    unanswered: UnansweredRequests(
      count: unanswered,
      olderThanHours: 3,
      topAreas: const [
        AreaDemand(areaId: 'shubra', name: 'شبرا', count: 6),
        AreaDemand(areaId: 'mataria', name: 'المطرية', count: 3),
      ],
    ),
    pendingVerifications: PendingVerifications(
      count: pendingVerifications,
      oldestAt: adminNow.subtract(const Duration(days: 2)),
    ),
    openComplaints: OpenComplaints(
      count: openComplaints,
      byReason: const {ComplaintReason.poorWork: 2, ComplaintReason.other: 1},
    ),
    pendingTopups: PendingTopups(
      count: pendingTopups,
      technicians: 4,
      consumers: 3,
    ),
    lowRated: lowRated,
  );
}

AreaCoverageReport testCoverage() {
  return const AreaCoverageReport(
    adsMinTechnicians: 10,
    areas: [
      AreaCoverage(
        id: 'nasr_city',
        name: 'مدينة نصر',
        city: 'القاهرة',
        isOpen: true,
        verifiedTechnicians: 24,
        requests: 48,
        gotOfferPercent: 98,
        adsActive: true,
      ),
      AreaCoverage(
        id: 'shubra',
        name: 'شبرا',
        city: 'القاهرة',
        isOpen: true,
        verifiedTechnicians: 6,
        requests: 12,
        gotOfferPercent: 67,
        adsActive: false,
      ),
      AreaCoverage(
        id: 'ain_shams',
        name: 'عين شمس',
        city: 'القاهرة',
        isOpen: false,
        verifiedTechnicians: 0,
        requests: 0,
        adsActive: false,
      ),
    ],
  );
}

VerificationSummary testVerificationSummary({
  String id = 'ver-1',
  String name = 'نورهان محمد',
  VerificationStatus status = VerificationStatus.pending,
  String? rejectionReason,
}) {
  return VerificationSummary(
    verificationId: id,
    technicianId: 'tech-$id',
    name: name,
    areaId: 'nasr_city',
    areaName: 'مدينة نصر',
    status: status,
    submittedAt: adminNow.subtract(const Duration(hours: 5)),
    suspended: false,
    rejectionReason: rejectionReason,
  );
}

VerificationDetail testVerificationDetail({
  String id = 'ver-1',
  VerificationStatus status = VerificationStatus.pending,
  String name = 'نورهان محمد',
  String? rejectionReason,
  int previousAttempts = 0,
}) {
  return VerificationDetail(
    verificationId: id,
    technicianId: 'tech-$id',
    status: status,
    submittedAt: adminNow.subtract(const Duration(hours: 5)),
    idFrontPath: 'tech/front.jpg',
    idBackPath: 'tech/back.jpg',
    selfiePath: 'tech/selfie.jpg',
    name: name,
    phone: '+201112345678',
    phoneConfirmed: true,
    shopName: 'ورشة النور',
    yearsExperience: 6,
    area: const NamedArea(id: 'nasr_city', name: 'مدينة نصر'),
    serviceRadiusKm: 10,
    workDays: const {6, 7, 1, 2, 3},
    suspended: false,
    previousAttempts: previousAttempts,
    areas: const [
      NamedArea(id: 'nasr_city', name: 'مدينة نصر'),
      NamedArea(id: 'heliopolis', name: 'مصر الجديدة'),
    ],
    services: const [
      OfferedService(
        serviceId: 'ac_repair',
        name: 'صيانة تكييف',
        startingPricePiastres: 25000,
      ),
    ],
    rejectionReason: rejectionReason,
  );
}

TopupReview testTopupReview({
  String id = 'topup-1',
  String? name = 'سامي حسن',
  UserRole role = UserRole.technician,
  TopupMethod method = TopupMethod.wallet,
  TopupStatus status = TopupStatus.pending,
  String senderAccount = '01012345678',
  String? accountPhone = '01012345678',
  String? rejectReason,
}) {
  return TopupReview(
    id: id,
    userId: name == null ? null : 'user-$id',
    name: name,
    accountPhone: accountPhone,
    role: role,
    uses: 10,
    amountPiastres: 25000,
    method: method,
    senderAccount: senderAccount,
    screenshotPath: 'user/proof.jpg',
    status: status,
    rejectReason: rejectReason,
    createdAt: adminNow.subtract(const Duration(hours: 2)),
  );
}

AdminRequest testAdminRequest({
  String id = 'req-1',
  AdminRequestStatus status = AdminRequestStatus.noOffers,
  String? technicianName,
  int? stars,
  bool hasOpenComplaint = false,
}) {
  return AdminRequest(
    id: id,
    code: 'R-1048',
    createdAt: adminNow.subtract(const Duration(hours: 4)),
    issue: RequestIssue.leaking,
    areaId: 'shubra',
    areaName: 'شبرا',
    consumerName: 'منى ك.',
    technicianName: technicianName,
    offerCount: status == AdminRequestStatus.noOffers ? 0 : 3,
    status: status,
    stars: stars,
    hasOpenComplaint: hasOpenComplaint,
    hasComplaint: hasOpenComplaint,
  );
}

AdminComplaint testComplaint({
  String id = 'complaint-1',
  String? details = 'الفني ماجاش في الميعاد <b>وماردش</b>',
  String? photoPath,
  DateTime? resolvedAt,
  String? resolutionNote,
  bool technicianSuspended = false,
}) {
  return AdminComplaint(
    id: id,
    requestId: 'req-1',
    requestCode: 'R-1042',
    reason: ComplaintReason.noShowOrLate,
    details: details,
    photoPath: photoPath,
    createdAt: adminNow.subtract(const Duration(hours: 6)),
    resolvedAt: resolvedAt,
    resolutionNote: resolutionNote,
    issue: RequestIssue.noisy,
    areaId: 'nasr_city',
    consumer: const ComplaintParty(
      id: 'consumer-1',
      name: 'خالد ف.',
      phone: '+201001234567',
    ),
    technician: ComplaintParty(
      id: 'tech-9',
      name: 'سامح ج.',
      phone: '+201112223334',
      suspended: technicianSuspended,
    ),
  );
}

AdminTechnician testAdminTechnician({
  String id = 'tech-1',
  String name = 'سامي حسن',
  AccountStatus status = AccountStatus.verified,
  String? suspensionReason,
}) {
  return AdminTechnician(
    id: id,
    name: name,
    phone: '+201112345678',
    areaId: 'nasr_city',
    areaName: 'مدينة نصر',
    status: status,
    balance: 4,
    pendingTopup: true,
    createdAt: DateTime(2026, 9),
    verificationStatus: VerificationStatus.approved,
    reviewCount: 12,
    platformJobs: 8,
    rating: 4.5,
    lastSignInAt: adminNow.subtract(const Duration(hours: 1)),
    suspensionReason: suspensionReason,
  );
}

AdminConsumer testAdminConsumer({
  String id = 'consumer-1',
  String name = 'نورهان محمد',
  AccountStatus status = AccountStatus.active,
  String? suspensionReason,
}) {
  return AdminConsumer(
    id: id,
    name: name,
    phone: '+201112345678',
    areaId: 'nasr_city',
    areaName: 'مدينة نصر',
    status: status,
    balance: 2,
    pendingTopup: false,
    createdAt: DateTime(2026, 9),
    requestsCount: 4,
    complaintsCount: 1,
    suspensionReason: suspensionReason,
  );
}

AuditEntry testAuditEntry({
  int id = 1,
  String action = 'approve_topup',
  String? adminName = 'أحمد',
  Map<String, Object?> details = const {'reason': 'تمام'},
}) {
  return AuditEntry(
    id: id,
    adminId: 'admin-1',
    adminName: adminName,
    action: action,
    targetType: 'topup',
    targetId: 'topup-1',
    details: details,
    createdAt: DateTime(2026, 10, 7, 11),
  );
}

AdminSettings testSettings() {
  return const AdminSettings(
    consumerFreeRequests: 3,
    technicianFreeJobs: 5,
    verifiedTechnicianTarget: 100,
    packs: [
      CreditPackSetting(
        id: 'pack-c5',
        role: UserRole.consumer,
        uses: 5,
        pricePiastres: 8000,
        sortOrder: 1,
        isActive: true,
      ),
      CreditPackSetting(
        id: 'pack-t10',
        role: UserRole.technician,
        uses: 10,
        pricePiastres: 25000,
        sortOrder: 1,
        isActive: true,
      ),
    ],
    paymentAccounts: [
      PaymentAccountSetting(
        method: TopupMethod.instapay,
        account: 'salahly@instapay',
        holderName: 'صلحلي',
        isActive: true,
      ),
      PaymentAccountSetting(
        method: TopupMethod.wallet,
        account: '01000000000',
        holderName: 'صلحلي',
        isActive: false,
      ),
    ],
  );
}
