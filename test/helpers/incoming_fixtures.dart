import 'package:bloc_test/bloc_test.dart';
import 'package:salahly/features/catalog/presentation/cubit/categories_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/incoming_request.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/cubit/incoming_requests_cubit.dart';
import 'package:salahly/features/marketplace/presentation/cubit/offer_cubit.dart';

class MockIncomingRequestsCubit extends MockCubit<IncomingRequestsState>
    implements IncomingRequestsCubit {}

class MockCategoriesCubit extends MockCubit<CategoriesState>
    implements CategoriesCubit {}

class MockOfferCubit extends MockCubit<OfferState> implements OfferCubit {}

/// The technician's offer on a request: 350 ج.م, tomorrow at 12:30.
MyOffer testMyOffer({
  OfferStatus status = OfferStatus.sent,
  String? note = 'هجيب معايا الفريون',
}) => MyOffer(
  id: 'offer-1',
  serviceId: 'ac_inspection_cleaning',
  pricePiastres: 35000,
  arriveAt: DateTime(2026, 10, 3, 12, 30),
  note: note,
  status: status,
);
