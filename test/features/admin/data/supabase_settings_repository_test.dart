import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/failures/account_failures.dart';
import 'package:salahly/features/admin/data/repositories/supabase_settings_repository.dart';
import 'package:salahly/features/admin/domain/entities/admin_settings.dart';
import 'package:salahly/features/admin/domain/failures/admin_failures.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';

import '../../../helpers/admin_fixtures.dart';
import '../../../helpers/admin_server.dart';

void main() {
  late AdminServer server;
  late SupabaseSettingsRepository repository;

  setUp(() {
    server = AdminServer();
    repository = SupabaseSettingsRepository(server.client);
  });

  test('reads the settings', () async {
    server.body = {
      'consumer_free_requests': 3,
      'technician_free_jobs': 5,
      'verified_technician_target': 100,
      'packs': [
        {
          'id': 'pack-c5',
          'role': 'consumer',
          'uses': 5,
          'price_piastres': 8000,
          'sort_order': 1,
          'is_active': true,
        },
        {
          'id': 'pack-t10',
          'role': 'technician',
          'uses': 10,
          'price_piastres': 25000,
          'sort_order': 1,
          'is_active': true,
        },
      ],
      'payment_accounts': [
        {
          'method': 'instapay',
          'account': 'salahly@instapay',
          'holder_name': 'صلحلي',
          'is_active': true,
        },
        {
          'method': 'wallet',
          'account': '01000000000',
          'holder_name': 'صلحلي',
          'is_active': false,
        },
      ],
    };

    final settings = valueOf(await repository.fetchSettings());

    expect(server.lastFunction, 'admin_get_settings');
    expect(settings, testSettings());
  });

  group('updateFreeUses', () {
    test('sends what changed and nulls for the rest', () async {
      server.body = <String, Object?>{};

      final result = await repository.updateFreeUses(consumerFreeRequests: 4);

      expect(result, isA<Ok<void>>());
      expect(server.lastFunction, 'admin_update_settings');
      expect(server.lastParams, {
        'p_consumer_free_requests': 4,
        'p_technician_free_jobs': null,
        'p_verified_technician_target': null,
      });
    });

    test('asks for a fresh sign-in', () async {
      server.fails('recent_login_required');

      expect(
        await repository.updateFreeUses(technicianFreeJobs: 6),
        failsWith(const RecentLoginRequiredFailure()),
      );
    });

    test('says when nothing was given', () async {
      server.fails('nothing_to_update');

      expect(
        await repository.updateFreeUses(),
        failsWith(const InvalidInputFailure()),
      );
    });
  });

  group('saveCreditPack', () {
    test('changes a pack by its id', () async {
      server.body = <String, Object?>{};

      await repository.saveCreditPack(
        const CreditPackDraft(
          id: 'pack-c5',
          role: UserRole.consumer,
          uses: 5,
          pricePiastres: 9000,
          sortOrder: 2,
          isActive: false,
        ),
      );

      expect(server.lastFunction, 'admin_save_credit_pack');
      expect(server.lastParams, {
        'p_id': 'pack-c5',
        'p_role': 'consumer',
        'p_uses': 5,
        'p_price_piastres': 9000,
        'p_is_active': false,
        'p_sort_order': 2,
      });
    });

    test('adds a pack without an id', () async {
      server.body = <String, Object?>{};

      await repository.saveCreditPack(
        const CreditPackDraft(
          role: UserRole.technician,
          uses: 20,
          pricePiastres: 40000,
          sortOrder: 3,
        ),
      );

      expect(server.lastParams['p_id'], isNull);
    });

    test('says when a pack with those uses is on sale', () async {
      server.fails('duplicate_pack');

      expect(
        await repository.saveCreditPack(
          const CreditPackDraft(
            role: UserRole.consumer,
            uses: 5,
            pricePiastres: 8000,
            sortOrder: 1,
          ),
        ),
        failsWith(const DuplicateFailure()),
      );
    });

    test('says when it would leave nothing on sale', () async {
      server.fails('last_active_pack');

      expect(
        await repository.saveCreditPack(
          const CreditPackDraft(
            id: 'pack-c5',
            role: UserRole.consumer,
            uses: 5,
            pricePiastres: 8000,
            sortOrder: 1,
            isActive: false,
          ),
        ),
        failsWith(const LastActiveFailure()),
      );
    });
  });

  test('changes a payment account', () async {
    server.body = <String, Object?>{};

    await repository.updatePaymentAccount(
      const PaymentAccountSetting(
        method: TopupMethod.wallet,
        account: '01000000000',
        holderName: 'صلحلي',
        isActive: true,
      ),
    );

    expect(server.lastFunction, 'admin_update_payment_account');
    expect(server.lastParams, {
      'p_method': 'wallet',
      'p_account': '01000000000',
      'p_holder_name': 'صلحلي',
      'p_is_active': true,
    });
  });

  test('says when no account would stay active', () async {
    server.fails('last_active_account');

    expect(
      await repository.updatePaymentAccount(
        const PaymentAccountSetting(
          method: TopupMethod.wallet,
          account: '01000000000',
          holderName: 'صلحلي',
          isActive: false,
        ),
      ),
      failsWith(const LastActiveFailure()),
    );
  });

  test('saves an area', () async {
    server.body = <String, Object?>{};

    await repository.saveArea(
      const AreaDraft(
        id: 'new_cairo',
        name: 'القاهرة الجديدة',
        city: 'القاهرة',
        centerLat: 30.03,
        centerLng: 31.47,
        isOpen: false,
      ),
    );

    expect(server.lastFunction, 'admin_save_service_area');
    expect(server.lastParams, {
      'p_id': 'new_cairo',
      'p_name_ar': 'القاهرة الجديدة',
      'p_city_ar': 'القاهرة',
      'p_center_lat': 30.03,
      'p_center_lng': 31.47,
      'p_is_open': false,
    });
  });

  test('opens and closes an area', () async {
    server.body = <String, Object?>{};

    await repository.setAreaOpen('shubra', isOpen: false);

    expect(server.lastFunction, 'admin_set_area_open');
    expect(server.lastParams, {'p_area_id': 'shubra', 'p_is_open': false});
  });

  test('says when the area is gone', () async {
    server.fails('area_not_found');

    expect(
      await repository.setAreaOpen('gone', isOpen: true),
      failsWith(const AdminNotFoundFailure()),
    );
  });
}
