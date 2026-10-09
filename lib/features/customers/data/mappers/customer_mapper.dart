import 'package:salahly/core/database/app_database.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';

Customer customerFromRow(CustomerRow row) => Customer(
  id: row.id,
  name: row.name,
  phone: row.phone == null ? null : PhoneNumber.tryParse(row.phone!),
  areaId: row.areaId,
  address: row.address,
  notes: row.notes,
  source: customerSourceFromWire(row.source),
  createdAt: row.createdAt.toLocal(),
);

CustomerUnit unitFromRow(CustomerUnitRow row) => CustomerUnit(
  id: row.id,
  customerId: row.customerId,
  brand: row.brand,
  capacityHp: row.capacityHp,
  room: row.room,
  installedYear: row.installedYear,
  nextServiceOn: CalendarDate.tryParse(row.nextServiceOn),
);

CustomerSource customerSourceFromWire(String wire) =>
    CustomerSource.values.asNameMap()[wire] ?? CustomerSource.manual;
