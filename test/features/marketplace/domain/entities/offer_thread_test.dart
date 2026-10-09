import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/marketplace/domain/entities/offer_thread.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';
import 'package:salahly/features/marketplace/presentation/incoming_labels.dart';

import '../../../../helpers/incoming_fixtures.dart';
import '../../../../helpers/marketplace_fixtures.dart';

void main() {
  group('poundsBelow', () {
    test('runs from one pound to the last whole pound under the price', () {
      expect(poundsBelow(35000), (min: 100, max: 34900));
      expect(poundsBelow(35050), (min: 100, max: 35000));
    });

    test('starts above the price asked for', () {
      expect(poundsBelow(35000, above: 30000), (min: 30100, max: 34900));
      expect(poundsBelow(35000, above: 30050), (min: 30100, max: 34900));
    });

    test('is null when no whole pound fits', () {
      expect(poundsBelow(100), isNull);
      expect(poundsBelow(35000, above: 34900), isNull);
      expect(poundsBelow(35000, above: 34950), isNull);
    });
  });

  group('what the consumer can ask for', () {
    test('any pound below the price, while she has counters left', () {
      expect(testOffer().counterRange, (min: 100, max: 34900));
    });

    test('nothing once the counters are used up', () {
      expect(testOffer(countersLeft: 0).counterRange, isNull);
    });

    test('nothing while the technician has yet to answer', () {
      final offer = testOffer(counterPricePiastres: 30000);

      expect(offer.isCountered, isTrue);
      expect(offer.counterRange, isNull);
    });

    test('nothing on an offer that is not open', () {
      expect(testOffer(status: OfferStatus.withdrawn).counterRange, isNull);
      expect(testOffer(status: OfferStatus.accepted).counterRange, isNull);
    });
  });

  group('what the technician can lower the price to', () {
    test('any pound below the price when nobody asked', () {
      expect(testMyOffer().reviseRange, (min: 100, max: 34900));
      expect(testMyOffer().isCountered, isFalse);
    });

    test('above the price the consumer asked for', () {
      final offer = testMyOffer(counterPricePiastres: 30000);

      expect(offer.isCountered, isTrue);
      expect(offer.reviseRange, (min: 30100, max: 34900));
    });

    test('nothing once the revisions are used up or the offer is closed', () {
      expect(testMyOffer(revisionsLeft: 0).reviseRange, isNull);
      expect(testMyOffer(status: OfferStatus.withdrawn).reviseRange, isNull);
    });
  });

  test('an offer taken back is its own standing', () {
    final request = testIncoming(
      myOffer: testMyOffer(status: OfferStatus.withdrawn),
    );

    expect(standingOf(request), IncomingStanding.withdrawn);
  });
}
