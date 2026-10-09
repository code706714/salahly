import 'package:bloc_test/bloc_test.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/request_window.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_cubit.dart';

class MockCategoriesCubit extends MockCubit<CategoriesState>
    implements CategoriesCubit {}

class MockOfferCubit extends MockCubit<OfferState> implements OfferCubit {}

class MockIncomingRequestsCubit extends MockCubit<IncomingRequestsState>
    implements IncomingRequestsCubit {}

/// The technician's offer on a request: 350 ج.م, tomorrow at 12:30.
MyOffer testMyOffer({
  OfferStatus status = OfferStatus.sent,
  String? note = 'هجيب معايا الفريون',
  int pricePiastres = 35000,
  int? counterPricePiastres,
  int revisionsLeft = MyOffer.maxRevisions,
}) => MyOffer(
  id: 'offer-1',
  serviceId: 'ac_inspection_cleaning',
  pricePiastres: pricePiastres,
  arriveAt: DateTime(2026, 10, 3, 12, 30),
  note: note,
  status: status,
  counterPricePiastres: counterPricePiastres,
  awaiting: counterPricePiastres == null
      ? OfferTurn.consumer
      : OfferTurn.technician,
  revisionsLeft: revisionsLeft,
);

/// Nourhan's request in Nasr City for tomorrow noon, sent at 7:40 pm on
/// Thursday 2 October 2026; every part can be changed.
IncomingRequest testIncoming({
  String id = 'request-1',
  String categoryId = 'ac',
  RequestIssue issue = RequestIssue.notCooling,
  String? description =
      'التكييف شغال بس الهوا اللي طالع مش ساقع، والوحدة اللي بره بتعمل صوت.',
  List<String> photoPaths = const [],
  String areaId = 'nasr_city',
  double distanceKm = 2.4,
  DateTime? day,
  RequestWindow window = RequestWindow.noon,
  DateTime? expiresAt,
  DateTime? createdAt,
  String consumerName = 'نورهان م.',
  Honorific honorific = Honorific.ms,
  RequestStatus status = RequestStatus.open,
  int sentTo = 5,
  int offerCount = 2,
  bool dismissed = false,
  MyOffer? myOffer,
}) => IncomingRequest(
  id: id,
  categoryId: categoryId,
  issue: issue,
  description: description,
  photoPaths: photoPaths,
  areaId: areaId,
  distanceKm: distanceKm,
  day: day ?? DateTime(2026, 10, 3),
  window: window,
  expiresAt: expiresAt ?? DateTime(2026, 10, 3, 15),
  createdAt: createdAt ?? DateTime(2026, 10, 2, 19, 40),
  consumerName: consumerName,
  consumerHonorific: honorific,
  status: status,
  sentTo: sentTo,
  offerCount: offerCount,
  dismissed: dismissed,
  myOffer: myOffer,
);
