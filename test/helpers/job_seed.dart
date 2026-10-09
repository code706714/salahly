import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';

import 'technician_app.dart';

T _ok<T>(Result<T> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Expected Ok, got $failure'),
};

/// Records a customer through [app]'s repository and returns their id.
/// Run inside `tester.runAsync`.
Future<String> seedCustomer(
  TechnicianApp app,
  String name, {
  String? phone,
}) async => _ok(
  await app.customers.addCustomer(
    CustomerDraft(
      name: name,
      phone: phone == null ? null : PhoneNumber.tryParse(phone),
    ),
  ),
).id;

/// Records a job through [app]'s repository, priced at [price] piastres
/// and moved [advance] steps along, and returns its id. Run inside
/// `tester.runAsync`.
Future<String> seedJob(
  TechnicianApp app,
  String customerId, {
  List<JobTag> tags = const [],
  String? description,
  DateTime? at,
  int price = 0,
  int advance = 0,
}) async {
  final id = _ok(
    await app.jobs.createJob(
      JobDraft(
        customerId: customerId,
        tags: tags,
        description: description,
        scheduledAt: at,
      ),
    ),
  );
  if (price > 0) {
    _ok(
      await app.jobs.saveQuote(
        id,
        items: [JobItemDraft(title: 'شغل', unitPricePiastres: price)],
        validDays: Job.defaultQuoteValidDays,
        status: QuoteStatus.accepted,
      ),
    );
  }
  for (var i = 0; i < advance; i++) {
    _ok(await app.jobs.advance(id));
  }
  return id;
}
