import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';

import '../../../../helpers/marketplace_fixtures.dart';

void main() {
  group('hasPendingPriceChange', () {
    test('is true while the technician waits for an answer', () {
      final details = testRequestDetails(job: testPriceChangeJob());

      expect(details.hasPendingPriceChange, isTrue);
    });

    test('is false once the job was called off', () {
      final details = testRequestDetails(
        status: RequestStatus.cancelled,
        job: testRequestJob(
          status: JobStatus.cancelled,
          quoteStatus: QuoteStatus.sent,
        ),
      );

      expect(details.hasPendingPriceChange, isFalse);
    });
  });

  group('cancelledByTechnician', () {
    test('follows the request when it says who cancelled', () {
      final details = testRequestDetails(
        status: RequestStatus.cancelled,
        cancelledBy: UserRole.technician,
      );

      expect(details.cancelledByTechnician, isTrue);
    });

    test('is true for a job the technician called off', () {
      final details = testRequestDetails(
        status: RequestStatus.cancelled,
        job: testRequestJob(status: JobStatus.cancelled),
      );

      expect(details.cancelledByTechnician, isTrue);
    });

    test('is false when the consumer cancelled', () {
      final details = testRequestDetails(
        status: RequestStatus.cancelled,
        cancelledBy: UserRole.consumer,
      );

      expect(details.cancelledByTechnician, isFalse);
    });
  });
}
