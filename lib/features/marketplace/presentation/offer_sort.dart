import 'package:salahly/features/marketplace/domain/entities/service_request.dart';

/// How the consumer orders the offers: "الأقرب", "الأرخص", "الأعلى تقييم".
enum OfferSort { nearest, cheapest, topRated }

/// [offers] in [sort] order. Offers without a distance or a rating go
/// last, and offers that tie keep the order they arrived in.
List<RequestOffer> sortOffers(List<RequestOffer> offers, OfferSort sort) {
  int compare(RequestOffer a, RequestOffer b) => switch (sort) {
    OfferSort.nearest => _nullsLast(a.distanceKm, b.distanceKm),
    OfferSort.cheapest => a.pricePiastres.compareTo(b.pricePiastres),
    OfferSort.topRated => switch (_nullsLast(
      a.technician.rating,
      b.technician.rating,
      descending: true,
    )) {
      0 => b.technician.reviewCount.compareTo(a.technician.reviewCount),
      final order => order,
    },
  };

  final arrived = offers.indexed.toList()
    ..sort((a, b) {
      final order = compare(a.$2, b.$2);
      return order != 0 ? order : a.$1.compareTo(b.$1);
    });
  return [for (final (_, offer) in arrived) offer];
}

int _nullsLast(num? a, num? b, {bool descending = false}) => switch ((a, b)) {
  (null, null) => 0,
  (null, _) => 1,
  (_, null) => -1,
  (final a?, final b?) => descending ? b.compareTo(a) : a.compareTo(b),
};
