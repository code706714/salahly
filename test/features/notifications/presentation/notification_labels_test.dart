import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/notifications/domain/entities/app_notification.dart';
import 'package:salahly/features/notifications/presentation/notification_labels.dart';

import '../../../helpers/notification_fixtures.dart';
import '../../../pump_app.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ar'));

  // A Tuesday.
  final now = DateTime(2026, 10, 6, 12);

  NotificationText consumerText(
    AppNotification notification, {
    String honorific = 'ms',
  }) => notificationText(
    l10n,
    notification,
    role: UserRole.consumer,
    honorific: honorific,
    today: now,
    categoryName: 'تكييف',
    areaName: 'مدينة نصر',
  );

  NotificationText technicianText(AppNotification notification) =>
      notificationText(
        l10n,
        notification,
        role: UserRole.technician,
        honorific: 'other',
        today: now,
        categoryName: 'تكييف',
        areaName: 'مدينة نصر',
      );

  AppNotification of(NotificationKind kind) => testNotification(kind, now: now);

  group("a consumer's notifications", () {
    test('an offer says who, how much and when', () {
      expect(
        consumerText(of(NotificationKind.offerReceived)),
        (
          title: 'وصلك عرض جديد',
          body: 'أحمد رمضان · 350 ج.م · الخميس 1:00',
        ),
      );
    });

    test('the steps of the job name the technician and the request', () {
      expect(consumerText(of(NotificationKind.jobConfirmed)), (
        title: 'أحمد رمضان أكّد معادك',
        body: 'تكييف مش بيبرّد',
      ));
      expect(consumerText(of(NotificationKind.jobStarted)), (
        title: 'أحمد رمضان بدأ الشغل',
        body: 'تكييف مش بيبرّد',
      ));
      expect(consumerText(of(NotificationKind.jobFinished)), (
        title: 'أحمد رمضان خلّص الشغلانة',
        body: 'تقييمك بيساعد جيرانك يختاروا صح',
      ));
    });

    test('"almost there" names the technician and suits either gender', () {
      final arriving = of(NotificationKind.technicianArriving);

      expect(consumerText(arriving), (
        title: 'أحمد رمضان قرّب يوصلك',
        body: 'خلّي تليفونك معاك.',
      ));
      expect(consumerText(arriving, honorific: 'mr'), consumerText(arriving));
      expect(
        consumerText(
          AppNotification(
            id: 'n4',
            kind: NotificationKind.technicianArriving,
            createdAt: _epoch,
          ),
        ).title,
        'الفني قرّب يوصلك',
      );
    });

    test('a new price is asked for in her grammar or his', () {
      final change = of(NotificationKind.priceChange);

      expect(consumerText(change), (
        title: 'أحمد رمضان عايز موافقتك على سعر جديد',
        body: 'مش هيكمّل غير لما توافقي.',
      ));
      expect(
        consumerText(change, honorific: 'mr').body,
        'مش هيكمّل غير لما توافق.',
      );
    });

    test('the price talk names the technician and suits either gender', () {
      expect(consumerText(of(NotificationKind.offerRevised)), (
        title: 'أحمد رمضان نزّل السعر',
        body: 'شوفي السعر الجديد واختاري.',
      ));
      expect(
        consumerText(of(NotificationKind.offerRevised), honorific: 'mr').body,
        'شوف السعر الجديد واختار.',
      );
      expect(consumerText(of(NotificationKind.offerWithdrawn)), (
        title: 'أحمد رمضان سحب عرضه',
        body: 'اختاري من العروض التانية.',
      ));
      expect(consumerText(of(NotificationKind.counterAccepted)), (
        title: 'أحمد رمضان وافق على سعرك',
        body: 'اتفقتوا على السعر. تابعي طلبك.',
      ));
    });

    test('a request the technician cancelled says the use came back', () {
      final cancelled = of(NotificationKind.requestCancelledByTechnician);

      expect(consumerText(cancelled), (
        title: 'أحمد رمضان ألغى طلبك',
        body: 'رجّعنالك الطلب المجاني. اطلبي فني تاني.',
      ));
      expect(
        consumerText(cancelled, honorific: 'mr').body,
        'رجّعنالك الطلب المجاني. اطلب فني تاني.',
      );
    });

    test('a request that ended without offers', () {
      expect(consumerText(of(NotificationKind.requestExpired)), (
        title: 'طلبك خلص من غير ما يوصلك عرض',
        body: 'رجّعنالك الطلب المجاني. اطلبي تاني بمعاد تاني.',
      ));
    });

    test('a checked transfer says how many requests it added', () {
      expect(consumerText(of(NotificationKind.topupApproved)), (
        title: 'التحويل اتأكد',
        body: 'اتضافوا 5 طلبات لرصيدك',
      ));
      expect(consumerText(of(NotificationKind.topupRejected)), (
        title: 'التحويل ماتقبلش',
        body: 'راجعي الصورة والرقم وجرّبي تاني.',
      ));
    });

    test('says only what happened once the request is gone', () {
      final bare = AppNotification(
        id: 'n1',
        kind: NotificationKind.requestCancelledByTechnician,
        createdAt: _epoch,
      );

      expect(consumerText(bare).title, 'الفني ألغى طلبك');
      expect(
        consumerText(
          AppNotification(
            id: 'n2',
            kind: NotificationKind.jobStarted,
            createdAt: _epoch,
          ),
        ).body,
        isNull,
      );
      expect(
        consumerText(
          AppNotification(
            id: 'n3',
            kind: NotificationKind.offerReceived,
            createdAt: _epoch,
          ),
        ).body,
        isNull,
      );
    });

    test('names the request by its problem alone before categories load', () {
      final text = notificationText(
        l10n,
        of(NotificationKind.jobStarted),
        role: UserRole.consumer,
        honorific: 'ms',
        today: now,
      );

      expect(text.body, 'مش بيبرّد');
    });
  });

  group("a technician's notifications", () {
    test('a new request names the area, the distance and the day', () {
      final text = technicianText(of(NotificationKind.newRequest));

      expect(text.title, 'طلب جديد في مدينة نصر');
      expect(
        text.body,
        'تكييف مش بيبرّد · 2.4 كم منك · الخميس 8 أكتوبر الضهر',
      );
    });

    test(
      'a price asked for follows the consumer, then points to the offer',
      () {
        expect(technicianText(of(NotificationKind.offerCountered)), (
          title: 'نورهان م. عايزة سعر أقل',
          body: 'افتح الطلب وردّ على السعر.',
        ));
      },
    );

    test('a new request without its area is only "new request"', () {
      final text = notificationText(
        l10n,
        of(NotificationKind.newRequest),
        role: UserRole.technician,
        honorific: 'other',
        today: now,
      );

      expect(text.title, 'طلب جديد');
    });

    test("being picked follows the consumer's honorific", () {
      final picked = of(NotificationKind.offerPicked);

      expect(technicianText(picked), (
        title: 'نورهان م. اختارت عرضك',
        body:
            'الخميس 1:00 · 350 ج.م. العنوان ورقمها ظهروا في الشغلانة. '
            'هتتخصم شغلانة من رصيدك لما تخلصها.',
      ));
      final he = AppNotification(
        id: 'n1',
        kind: NotificationKind.offerPicked,
        createdAt: _epoch,
        consumerName: 'حسام ع.',
        consumerHonorific: Honorific.mr,
      );
      expect(technicianText(he), (
        title: 'حسام ع. اختار عرضك',
        body:
            'العنوان ورقمه ظهروا في الشغلانة. '
            'هتتخصم شغلانة من رصيدك لما تخلصها.',
      ));
    });

    test('a pick that went elsewhere and a cancellation', () {
      expect(technicianText(of(NotificationKind.offerNotPicked)), (
        title: 'نورهان م. اختارت فني تاني',
        body: 'ماتخصمش من رصيدك حاجة. فيه طلبات تانية جاية.',
      ));
      expect(technicianText(of(NotificationKind.requestCancelledByConsumer)), (
        title: 'نورهان م. لغت الطلب',
        body: 'الشغلانة ماتخصمتش من رصيدك.',
      ));
    });

    test('without the consumer it says "the client"', () {
      final text = technicianText(
        AppNotification(
          id: 'n1',
          kind: NotificationKind.requestCancelledByConsumer,
          createdAt: _epoch,
        ),
      );

      expect(text.title, 'العميل لغى الطلب');
    });

    test('verification and transfers', () {
      expect(
        technicianText(of(NotificationKind.verificationApproved)).title,
        'حسابك اتوثّق',
      );
      expect(
        technicianText(of(NotificationKind.verificationRejected)).title,
        'حسابك ماتوثّقش',
      );
      expect(technicianText(of(NotificationKind.topupApproved)), (
        title: 'التحويل اتأكد',
        body: 'اتضافوا 5 شغلانات لرصيدك',
      ));
      expect(
        technicianText(of(NotificationKind.topupRejected)).body,
        'راجع الصورة والرقم وجرّب تاني.',
      );
    });

    test('says nothing of the uses when the transfer is gone', () {
      expect(
        technicianText(
          AppNotification(
            id: 'n1',
            kind: NotificationKind.topupApproved,
            createdAt: _epoch,
          ),
        ).body,
        isNull,
      );
    });
  });

  group('every kind has a text', () {
    for (final kind in NotificationKind.values) {
      test(kind.name, () {
        expect(consumerText(of(kind)).title, isNotEmpty);
        expect(technicianText(of(kind)).title, isNotEmpty);
      });
    }
  });

  group('time', () {
    String ago(Duration duration) => notificationTimeLabel(
      l10n,
      now.subtract(duration),
      now: now,
    );

    test('is short and relative today', () {
      expect(ago(const Duration(seconds: 30)), 'دلوقتي');
      expect(ago(const Duration(minutes: 20)), '20 د');
      expect(ago(const Duration(hours: 1, minutes: 5)), 'ساعة');
      expect(ago(const Duration(hours: 3)), '3 س');
    });

    test('is the clock later in the day', () {
      expect(
        notificationTimeLabel(
          l10n,
          DateTime(2026, 10, 6, 5, 5),
          now: DateTime(2026, 10, 6, 13),
        ),
        '5:05 ص',
      );
      expect(
        notificationTimeLabel(
          l10n,
          DateTime(2026, 10, 6, 0, 30),
          now: DateTime(2026, 10, 6, 23),
        ),
        '12:30 ص',
      );
      expect(
        notificationTimeLabel(
          l10n,
          DateTime(2026, 10, 6, 14, 30),
          now: DateTime(2026, 10, 6, 23),
        ),
        '2:30 م',
      );
    });

    test('is a day name or a date before today', () {
      expect(ago(const Duration(days: 1)), 'امبارح');
      expect(ago(const Duration(days: 3)), 'السبت');
      expect(ago(const Duration(days: 10)), '26 سبتمبر');
    });

    test('groups by today, yesterday and earlier', () {
      String heading(Duration duration) => notificationDayHeading(
        l10n,
        now.subtract(duration),
        now: now,
      );

      expect(heading(const Duration(hours: 2)), 'النهارده');
      expect(heading(const Duration(days: 1)), 'امبارح');
      expect(heading(const Duration(days: 5)), 'قبل كده');
    });
  });

  group('where a notification leads', () {
    test("a consumer's goes to the request, or the list without one", () {
      expect(
        notificationRoute(
          of(NotificationKind.offerReceived),
          UserRole.consumer,
        ),
        AppRoutes.request('request-1'),
      );
      expect(
        notificationRoute(
          testNotification(
            NotificationKind.requestCancelledByTechnician,
            requestId: null,
          ),
          UserRole.consumer,
        ),
        AppRoutes.consumerRequests,
      );
    });

    test('a price talk opens the request, on either side', () {
      for (final kind in [
        NotificationKind.offerRevised,
        NotificationKind.offerWithdrawn,
        NotificationKind.counterAccepted,
      ]) {
        expect(
          notificationRoute(of(kind), UserRole.consumer),
          AppRoutes.request('request-1'),
          reason: kind.name,
        );
      }
      expect(
        notificationRoute(
          of(NotificationKind.offerCountered),
          UserRole.technician,
        ),
        AppRoutes.incomingRequest('request-1'),
      );
    });

    test('"almost there" opens the request the technician is coming for', () {
      expect(
        notificationRoute(
          of(NotificationKind.technicianArriving),
          UserRole.consumer,
        ),
        AppRoutes.request('request-1'),
      );
    });

    test("a technician's goes to the incoming request, or the list", () {
      expect(
        notificationRoute(of(NotificationKind.newRequest), UserRole.technician),
        AppRoutes.incomingRequest('request-1'),
      );
      expect(
        notificationRoute(
          testNotification(NotificationKind.offerPicked, requestId: null),
          UserRole.technician,
        ),
        AppRoutes.incomingRequests,
      );
    });

    test('a transfer goes to the balance of its side', () {
      expect(
        notificationRoute(
          of(NotificationKind.topupApproved),
          UserRole.consumer,
        ),
        AppRoutes.consumerBalance,
      );
      expect(
        notificationRoute(
          of(NotificationKind.topupRejected),
          UserRole.technician,
        ),
        AppRoutes.technicianBalance,
      );
    });

    test("verification goes to the technician's account", () {
      expect(
        notificationRoute(
          of(NotificationKind.verificationApproved),
          UserRole.technician,
        ),
        AppRoutes.technicianAccount,
      );
    });
  });
}

final _epoch = DateTime(2026, 10, 6);
