import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/domain/entities/technician_card.dart';

// Builders for marketplace entities, with the designs' sample data.

const testHome = ConsumerAddress(
  id: 'address-1',
  label: 'البيت',
  areaId: 'nasr_city',
  details: '14 شارع عباس العقاد، الحي العاشر · الدور الخامس',
);

const testMomsHome = ConsumerAddress(
  id: 'address-2',
  label: 'بيت ماما',
  areaId: 'heliopolis',
  details: 'شارع النزهة',
);

TechnicianCard testTechnicianCard({
  String id = 'tech-1',
  String name = 'محمود السيد',
  double? rating = 4.8,
  int reviewCount = 126,
  int jobsDone = 214,
  bool verified = true,
}) => TechnicianCard(
  id: id,
  name: name,
  avatarPath: '$id/avatar.jpg',
  yearsExperience: 12,
  verified: verified,
  rating: rating,
  reviewCount: reviewCount,
  jobsDone: jobsDone,
);

RequestOffer testOffer({
  String id = 'offer-1',
  int pricePiastres = 35000,
  DateTime? arriveAt,
  String? note = 'السعر شامل الكشف والتنظيف.',
  OfferStatus status = OfferStatus.sent,
  double distanceKm = 2.4,
  TechnicianCard? technician,
}) => RequestOffer(
  id: id,
  pricePiastres: pricePiastres,
  arriveAt: arriveAt ?? DateTime(2026, 10, 3, 12),
  note: note,
  status: status,
  distanceKm: distanceKm,
  createdAt: DateTime(2026, 10, 2, 20, 5),
  technician: technician ?? testTechnicianCard(),
);

/// The design's three offers: Yasser, Mahmoud and Ahmed.
List<RequestOffer> testOffers() => [
  testOffer(
    pricePiastres: 40000,
    arriveAt: DateTime(2026, 10, 3, 12, 30),
    note: 'غالباً محتاج تنظيف وشحن بسيط، هكشف وأقولك.',
    distanceKm: 1.2,
    technician: testTechnicianCard(
      id: 'tech-2',
      name: 'ياسر عبد الحميد',
      rating: 4.9,
      reviewCount: 31,
      jobsDone: 40,
    ),
  ),
  testOffer(id: 'offer-2', arriveAt: DateTime(2026, 10, 3, 12)),
  testOffer(
    id: 'offer-3',
    pricePiastres: 30000,
    arriveAt: DateTime(2026, 10, 3, 14, 30),
    note: 'كشف وتنظيف داخلي وخارجي.',
    distanceKm: 4.1,
    technician: testTechnicianCard(
      id: 'tech-3',
      name: 'أحمد رمضان',
      rating: 4.6,
      reviewCount: 58,
      jobsDone: 97,
    ),
  ),
];

RequestJob testRequestJob({
  JobStatus status = JobStatus.confirmed,
  QuoteStatus quoteStatus = QuoteStatus.accepted,
  List<PriceLine>? items,
  DateTime? quoteSentAt,
}) {
  final lines =
      items ??
      const [
        PriceLine(
          title: 'كشف وتنظيف',
          unitPricePiastres: 35000,
          quantity: 1,
          addedLater: false,
        ),
      ];
  return RequestJob(
    status: status,
    scheduledAt: DateTime(2026, 10, 3, 12),
    confirmedAt: status == JobStatus.unconfirmed
        ? null
        : DateTime(2026, 10, 2, 21),
    startedAt: switch (status) {
      JobStatus.started || JobStatus.finished || JobStatus.paid => DateTime(
        2026,
        10,
        3,
        12,
        10,
      ),
      _ => null,
    },
    finishedAt: switch (status) {
      JobStatus.finished || JobStatus.paid => DateTime(2026, 10, 3, 14, 10),
      _ => null,
    },
    quoteStatus: quoteStatus,
    quoteSentAt: quoteSentAt ?? DateTime(2026, 10, 2, 20, 5),
    items: lines,
    totalPiastres: lines.fold(0, (sum, line) => sum + line.totalPiastres),
  );
}

/// The design's price change: freon added after the inspection.
RequestJob testPriceChangeJob() => testRequestJob(
  status: JobStatus.started,
  quoteStatus: QuoteStatus.sent,
  quoteSentAt: DateTime(2026, 10, 3, 12, 35),
  items: const [
    PriceLine(
      title: 'كشف وتنظيف',
      unitPricePiastres: 35000,
      quantity: 1,
      addedLater: false,
    ),
    PriceLine(
      title: 'شحن فريون جزئي',
      unitPricePiastres: 30000,
      quantity: 1,
      addedLater: true,
    ),
  ],
);

/// A request; open with no offers unless told otherwise. Passing [job]
/// makes it assigned to the second of [offers].
RequestDetails testRequestDetails({
  String id = 'request-1',
  RequestStatus? status,
  List<RequestOffer>? offers,
  RequestJob? job,
  RequestWindow window = RequestWindow.noon,
  UserRole? cancelledBy,
  SubmittedReview? review,
  bool widened = false,
  bool hasOpenComplaint = false,
  int sentTo = 5,
  int seenBy = 3,
}) {
  final assigned = job != null;
  final shownOffers =
      offers ??
      (assigned
          ? [testOffer(id: 'offer-2', status: OfferStatus.accepted)]
          : const <RequestOffer>[]);
  return RequestDetails(
    id: id,
    categoryId: 'ac',
    issue: RequestIssue.notCooling,
    description: 'التكييف شغال بس الهوا مش ساقع، والوحدة اللي بره بتعمل صوت.',
    areaId: 'nasr_city',
    addressLabel: testHome.label,
    addressDetails: testHome.details,
    day: DateTime(2026, 10, 3),
    window: window,
    expiresAt: window.endOn(DateTime(2026, 10, 3)),
    status: status ?? (assigned ? RequestStatus.assigned : RequestStatus.open),
    cancelledBy: cancelledBy,
    widened: widened,
    createdAt: DateTime(2026, 10, 2, 19, 40),
    chosenAt: assigned ? DateTime(2026, 10, 2, 20, 5) : null,
    sentTo: sentTo,
    seenBy: seenBy,
    offers: shownOffers,
    chosenOfferId: assigned ? 'offer-2' : null,
    technicianPhone: assigned ? '+201009990041' : null,
    job: job,
    review: review,
    hasOpenComplaint: hasOpenComplaint,
  );
}

RequestSummary testRequestSummary({
  String id = 'request-1',
  RequestIssue issue = RequestIssue.notCooling,
  RequestStatus status = RequestStatus.open,
  int offerCount = 0,
  JobStatus? jobStatus,
  UserRole? cancelledBy,
  int? reviewStars,
  String? technicianName,
}) => RequestSummary(
  id: id,
  categoryId: 'ac',
  issue: issue,
  status: status,
  cancelledBy: cancelledBy,
  day: DateTime(2026, 10, 3),
  window: RequestWindow.noon,
  createdAt: DateTime(2026, 10, 2, 19, 40),
  offerCount: offerCount,
  technicianId: technicianName == null ? null : 'tech-1',
  technicianName: technicianName,
  pricePiastres: technicianName == null ? null : 35000,
  jobStatus: jobStatus,
  scheduledAt: technicianName == null ? null : DateTime(2026, 10, 3, 12),
  reviewStars: reviewStars,
);

TechnicianPublicProfile testTechnicianProfile({TechnicianCard? card}) =>
    TechnicianPublicProfile(
      card: card ?? testTechnicianCard(),
      onTimePercent: 98,
      areaIds: const ['nasr_city', 'heliopolis', 'nozha'],
      services: const [
        ServicePrice(
          serviceId: 'ac_inspection_cleaning',
          startingPricePiastres: 35000,
        ),
        ServicePrice(
          serviceId: 'ac_freon_recharge',
          startingPricePiastres: 65000,
        ),
      ],
      reviews: [
        PublicReview(
          author: 'دعاء م.',
          stars: 5,
          comment:
              'جه في معاده بالظبط ونضّف التكييف كويس، وفهمني المشكلة كانت فين.',
          tags: const {ReviewTag.onTime},
          issue: RequestIssue.needsCleaning,
          createdAt: DateTime(2026, 9, 18),
        ),
        PublicReview(
          author: 'حسام ع.',
          stars: 4,
          comment: 'شغله نضيف ومحترم، بس اتأخر نص ساعة.',
          issue: RequestIssue.notCooling,
          createdAt: DateTime(2026, 9, 2),
        ),
      ],
    );

IncomingRequest testIncomingRequest({
  String id = 'request-1',
  RequestStatus status = RequestStatus.open,
  int offerCount = 2,
  MyOffer? myOffer,
  Honorific honorific = Honorific.ms,
  List<String> photoPaths = const [],
}) => IncomingRequest(
  id: id,
  categoryId: 'ac',
  issue: RequestIssue.notCooling,
  description:
      'التكييف شغال بس الهوا اللي طالع مش ساقع، والوحدة اللي بره بتعمل صوت.',
  photoPaths: photoPaths,
  areaId: 'nasr_city',
  distanceKm: 2.4,
  day: DateTime(2026, 10, 3),
  window: RequestWindow.noon,
  expiresAt: DateTime(2026, 10, 3, 15),
  createdAt: DateTime(2026, 10, 2, 19, 40),
  consumerName: 'نورهان م.',
  consumerHonorific: honorific,
  status: status,
  sentTo: 5,
  offerCount: offerCount,
  dismissed: false,
  myOffer: myOffer,
);
