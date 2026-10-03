import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/storage/local_photo_store.dart';
import 'package:salahly/core/sync/local_changes.dart';
import 'package:salahly/core/sync/sync_tables.dart';
import 'package:salahly/features/customers/data/repositories/drift_customers_repository.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';
import 'package:salahly/features/jobs/data/repositories/drift_jobs_repository.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late DriftCustomersRepository repository;
  late DriftJobsRepository jobs;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 10, 2, 9);
    final changes = LocalChanges();
    repository = DriftCustomersRepository(
      database: db,
      changes: changes,
      clock: () => now,
    );
    jobs = DriftJobsRepository(
      database: db,
      photos: LocalPhotoStore(Directory.systemTemp.createTempSync()),
      changes: changes,
      currentUserId: () => 'user-1',
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  T ok<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw TestFailure('Expected Ok, got $failure'),
  };

  final phone = PhoneNumber.tryParse('01228703314')!;

  Future<Customer> addKarim() async => ok(
    await repository.addCustomer(
      CustomerDraft(
        name: '  أ. كريم   منصور ',
        phone: phone,
        areaId: 'heliopolis',
        address: '7 شارع الحجاز ',
        notes: '',
      ),
    ),
  );

  Future<String> finishedJob(
    String customerId,
    int pricePiastres, {
    int paidPiastres = 0,
  }) async {
    final id = ok(await jobs.createJob(JobDraft(customerId: customerId)));
    ok(
      await jobs.saveQuote(
        id,
        items: [JobItemDraft(title: 'شغل', unitPricePiastres: pricePiastres)],
        validDays: 3,
        status: QuoteStatus.draft,
      ),
    );
    for (var i = 0; i < 3; i++) {
      ok(await jobs.advance(id));
    }
    if (paidPiastres > 0) {
      ok(
        await jobs.recordPayment(
          id,
          amountPiastres: paidPiastres,
          method: PaymentMethod.cash,
        ),
      );
    }
    return id;
  }

  test('saves a customer the way the server would store them', () async {
    final customer = await addKarim();

    expect(customer.name, 'أ. كريم منصور');
    expect(customer.address, '7 شارع الحجاز');
    expect(customer.notes, isNull);
    final row = await db.select(db.customers).getSingle();
    expect(row.phone, '+201228703314');
    expect(row.source, 'manual');
    final queued = await db.select(db.outbox).getSingle();
    expect((queued.entity, queued.rowId), (SyncEntity.customers, customer.id));
  });

  test('finds a customer by phone to avoid duplicates', () async {
    final customer = await addKarim();

    expect(await repository.findByPhone(phone), customer);
    expect(
      await repository.findByPhone(PhoneNumber.tryParse('01000000000')!),
      isNull,
    );
  });

  test('updates and clears fields', () async {
    final customer = await addKarim();

    ok(
      await repository.updateCustomer(
        customer.id,
        const CustomerDraft(name: 'أ. كريم'),
      ),
    );

    final record = (await repository.watchCustomer(customer.id).first)!;
    expect(record.customer.name, 'أ. كريم');
    expect(record.customer.phone, isNull);
    expect(record.customer.areaId, isNull);
  });

  test("keeps a customer's air conditioners", () async {
    final customer = await addKarim();
    ok(
      await repository.addUnit(
        customer.id,
        CustomerUnitDraft(
          brand: 'شارب',
          capacityHp: 1.5,
          room: 'الصالة',
          installedYear: 2021,
          nextServiceOn: DateTime(2027, 4),
        ),
      ),
    );
    final unit =
        (await repository.watchCustomer(customer.id).first)!.units.single;
    expect(unit.capacityHp, 1.5);
    expect(unit.nextServiceOn, DateTime(2027, 4));

    ok(
      await repository.updateUnit(
        unit.id,
        const CustomerUnitDraft(brand: 'كارير', capacityHp: 2.25),
      ),
    );
    final updated =
        (await repository.watchCustomer(customer.id).first)!.units.single;
    expect(updated.brand, 'كارير');
    expect(updated.room, isNull);

    ok(await repository.deleteUnit(unit.id));
    expect((await repository.watchCustomer(customer.id).first)!.units, isEmpty);
  });

  group('watchCustomers', () {
    test('summarises what each customer owes and their visits', () async {
      final karim = await addKarim();
      final first = await finishedJob(karim.id, 170000, paidPiastres: 50000);
      now = now.add(const Duration(days: 6));
      await finishedJob(karim.id, 65000, paidPiastres: 65000);
      final next = ok(
        await jobs.createJob(
          JobDraft(
            customerId: karim.id,
            scheduledAt: DateTime(2026, 10, 9, 13),
          ),
        ),
      );
      ok(
        await jobs.cancel(
          ok(await jobs.createJob(JobDraft(customerId: karim.id))),
        ),
      );
      ok(
        await repository.addUnit(
          karim.id,
          const CustomerUnitDraft(brand: 'شارب'),
        ),
      );

      final summary =
          (await repository.watchCustomers(today: DateTime(2026, 10, 8)).first)
              .single;

      expect(summary.customer.id, karim.id);
      expect(summary.jobCount, 3);
      expect(summary.unitCount, 1);
      expect(summary.owedPiastres, 120000);
      expect(summary.owedSince, DateTime(2026, 10, 2, 9));
      expect(summary.lastFinishedAt, DateTime(2026, 10, 8, 9));
      expect(summary.nextScheduledAt, DateTime(2026, 10, 9, 13));
      expect(first, isNotEmpty);
      expect(next, isNotEmpty);
    });

    test("gives the soonest next service of a customer's units", () async {
      final karim = await addKarim();
      for (final day in [DateTime(2027, 4), null, DateTime(2026, 12, 15)]) {
        ok(
          await repository.addUnit(
            karim.id,
            CustomerUnitDraft(nextServiceOn: day),
          ),
        );
      }
      final first =
          (await repository.watchCustomer(karim.id).first)!.units.first;
      ok(
        await repository.updateUnit(
          first.id,
          CustomerUnitDraft(nextServiceOn: DateTime(2026, 11)),
        ),
      );
      ok(await repository.deleteUnit(first.id));

      final summary =
          (await repository.watchCustomers(today: DateTime(2026, 10, 2)).first)
              .single;

      expect(summary.nextServiceOn, DateTime(2026, 12, 15));
    });

    test('has no next service without dated units', () async {
      final karim = await addKarim();
      ok(await repository.addUnit(karim.id, const CustomerUnitDraft()));

      final summary =
          (await repository.watchCustomers(today: DateTime(2026, 10, 2)).first)
              .single;

      expect(summary.nextServiceOn, isNull);
    });

    test('lists the most recently active customers first', () async {
      final karim = await addKarim();
      now = now.add(const Duration(hours: 1));
      final sherif = ok(
        await repository.addCustomer(const CustomerDraft(name: 'م. شريف عادل')),
      );
      now = now.add(const Duration(hours: 1));
      ok(await jobs.createJob(JobDraft(customerId: karim.id)));

      final customers = await repository
          .watchCustomers(today: DateTime(2026, 10, 2))
          .first;

      expect(customers.map((summary) => summary.customer.id), [
        karim.id,
        sherif.id,
      ]);
    });
  });

  test('deleting a customer deletes their units and jobs too', () async {
    final karim = await addKarim();
    ok(await repository.addUnit(karim.id, const CustomerUnitDraft()));
    ok(await jobs.createJob(JobDraft(customerId: karim.id)));
    await db.delete(db.outbox).go();

    ok(await repository.deleteCustomer(karim.id));

    expect(
      await repository.watchCustomers(today: DateTime(2026, 10, 2)).first,
      isEmpty,
    );
    expect(await repository.watchCustomer(karim.id).first, isNull);
    expect(await jobs.watchOpen().first, isEmpty);
    expect(
      (await db.select(db.outbox).get()).map((entry) => entry.entity).toSet(),
      {SyncEntity.customers, SyncEntity.customerUnits, SyncEntity.jobs},
    );
  });
}
