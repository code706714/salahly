import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/data/models/push_notice_model.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';

void main() {
  const requestId = '11111111-2222-4333-8444-555555555555';

  test('reads the kind, the side, the request and the text', () {
    expect(
      PushNoticeModel.fromMessage(
        data: {
          'kind': 'technician_arriving',
          'role': 'consumer',
          'request_id': requestId,
        },
        title: 'محمود قرّب يوصلك',
        body: 'خلّي تليفونك معاك.',
      ),
      const PushNotice(
        kind: NotificationKind.technicianArriving,
        role: UserRole.consumer,
        requestId: requestId,
        title: 'محمود قرّب يوصلك',
        body: 'خلّي تليفونك معاك.',
      ),
    );
  });

  test('reads the kinds of the price talk', () {
    const kinds = {
      'offer_countered': (NotificationKind.offerCountered, UserRole.technician),
      'offer_revised': (NotificationKind.offerRevised, UserRole.consumer),
      'offer_withdrawn': (NotificationKind.offerWithdrawn, UserRole.consumer),
      'counter_accepted': (NotificationKind.counterAccepted, UserRole.consumer),
    };
    for (final MapEntry(key: wire, value: (kind, role)) in kinds.entries) {
      expect(
        PushNoticeModel.fromMessage(
          data: {'kind': wire, 'role': role.name, 'request_id': requestId},
        ),
        PushNotice(kind: kind, role: role, requestId: requestId),
        reason: wire,
      );
    }
  });

  test('reads a message that is not about a request', () {
    final notice = PushNoticeModel.fromMessage(
      data: {'kind': 'topup_approved', 'role': 'technician'},
    )!;

    expect(notice.kind, NotificationKind.topupApproved);
    expect(notice.role, UserRole.technician);
    expect(notice.requestId, isNull);
    expect(notice.title, isNull);
  });

  test('drops a message of a kind this version does not know', () {
    expect(
      PushNoticeModel.fromMessage(
        data: {'kind': 'from_the_future', 'role': 'consumer'},
      ),
      isNull,
    );
  });

  test('drops a message with no side or an unknown one', () {
    expect(PushNoticeModel.fromMessage(data: {'kind': 'job_started'}), isNull);
    expect(
      PushNoticeModel.fromMessage(
        data: {'kind': 'job_started', 'role': 'admin'},
      ),
      isNull,
    );
    expect(PushNoticeModel.fromMessage(data: {}), isNull);
  });

  test('ignores a request id that is not a uuid', () {
    for (final bad in ['../admin', 'request-1', '', 42, null]) {
      expect(
        PushNoticeModel.fromMessage(
          data: {'kind': 'job_started', 'role': 'consumer', 'request_id': bad},
        )!.requestId,
        isNull,
        reason: '$bad',
      );
    }
  });
}
