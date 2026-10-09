import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/account/domain/entities/user_profile.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/account/domain/entities/verification_status.dart';
import 'package:salahly/features/account/presentation/cubit/session_cubit.dart';
import 'package:salahly/features/auth/domain/entities/auth_user.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';

import 'technician_app.dart';

/// Signed in as the technician محمود عبد الله, who signs the messages.
const technicianSession = SessionReady(
  user: AuthUser(id: 'user-1'),
  profile: UserProfile(
    id: 'user-1',
    phone: '+201002345678',
    fullName: 'محمود عبد الله',
    activeRole: UserRole.technician,
    technician: TechnicianProfile(
      verificationStatus: VerificationStatus.approved,
      jobCredits: 3,
    ),
  ),
);

/// A customer with sensible defaults; override what a test is about.
Customer testCustomer({
  String id = 'customer-1',
  String name = 'أ. كريم منصور',
  String? phone = '01228703314',
  String? areaId,
  String? address,
  String? notes,
  CustomerSource source = CustomerSource.manual,
}) => Customer(
  id: id,
  name: name,
  phone: phone == null ? null : PhoneNumber.tryParse(phone),
  areaId: areaId,
  address: address,
  notes: notes,
  source: source,
  createdAt: DateTime(2026, 9),
);

/// A customer as the customers list shows them.
CustomerSummary testCustomerSummary(
  Customer customer, {
  int jobCount = 0,
  int unitCount = 0,
  int owedPiastres = 0,
  DateTime? owedSince,
  DateTime? lastFinishedAt,
  DateTime? nextScheduledAt,
  DateTime? nextServiceOn,
}) => CustomerSummary(
  customer: customer,
  jobCount: jobCount,
  unitCount: unitCount,
  owedPiastres: owedPiastres,
  owedSince: owedSince,
  lastFinishedAt: lastFinishedAt,
  nextScheduledAt: nextScheduledAt,
  nextServiceOn: nextServiceOn,
);

/// An air conditioner of `customer-1`.
CustomerUnit testUnit({
  String id = 'unit-1',
  String? brand = 'شارب',
  double? capacityHp = 1.5,
  String? room = 'الصالة',
  int? installedYear = 2021,
  DateTime? nextServiceOn,
}) => CustomerUnit(
  id: id,
  customerId: 'customer-1',
  brand: brand,
  capacityHp: capacityHp,
  room: room,
  installedYear: installedYear,
  nextServiceOn: nextServiceOn,
);

/// Puts a customer with a known [id] straight into [app]'s database, for
/// screens opened by id.
Future<void> seedCustomer(
  WidgetTester tester,
  TechnicianApp app, {
  String id = 'customer-1',
  String name = 'أ. كريم منصور',
}) async {
  final now = DateTime.now().toUtc();
  await tester.runAsync(
    () => app.database
        .into(app.database.customers)
        .insert(
          CustomerRow(
            id: id,
            name: name,
            source: 'manual',
            createdAt: now,
            updatedAt: now,
          ),
        ),
  );
  await app.settle(tester);
}
