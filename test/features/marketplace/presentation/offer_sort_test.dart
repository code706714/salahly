import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/offer_sort.dart';

import '../../../helpers/marketplace_fixtures.dart';

void main() {
  RequestOffer offer(
    String id, {
    int price = 35000,
    double? distanceKm,
    double? rating,
    int reviewCount = 10,
  }) => RequestOffer(
    id: id,
    pricePiastres: price,
    arriveAt: DateTime(2026, 10, 7, 12),
    status: OfferStatus.sent,
    distanceKm: distanceKm,
    createdAt: DateTime(2026, 10, 6, 9),
    technician: testTechnicianCard(
      id: 'tech-$id',
      rating: rating,
      reviewCount: reviewCount,
    ),
  );

  List<String> ids(List<RequestOffer> offers) => [
    for (final offer in offers) offer.id,
  ];

  test('nearest first, offers without a distance last', () {
    final offers = [
      offer('a'),
      offer('b', distanceKm: 4.1),
      offer('c', distanceKm: 1.2),
    ];

    expect(ids(sortOffers(offers, OfferSort.nearest)), ['c', 'b', 'a']);
  });

  test('cheapest first, ties in the order they arrived', () {
    final offers = [
      offer('a', price: 40000),
      offer('b', price: 30000),
      offer('c', price: 30000),
    ];

    expect(ids(sortOffers(offers, OfferSort.cheapest)), ['b', 'c', 'a']);
  });

  test('top rated first, then more reviews, unrated last', () {
    final offers = [
      offer('a'),
      offer('b', rating: 4.6, reviewCount: 58),
      offer('c', rating: 4.9, reviewCount: 3),
      offer('d', rating: 4.9, reviewCount: 31),
    ];

    expect(ids(sortOffers(offers, OfferSort.topRated)), ['d', 'c', 'b', 'a']);
  });

  test('leaves the list it was given alone', () {
    final offers = [offer('a', price: 2), offer('b', price: 1)];

    sortOffers(offers, OfferSort.cheapest);

    expect(ids(offers), ['a', 'b']);
  });
}
