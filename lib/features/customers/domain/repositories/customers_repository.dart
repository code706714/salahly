import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/entities/customer_summary.dart';
import 'package:salahly/features/customers/domain/entities/customer_unit.dart';

/// The technician's customers, kept on the phone and synced in the
/// background. Writes succeed offline.
abstract interface class CustomersRepository {
  /// Every customer, most recently active first. [today] is the start of
  /// the local day, from which upcoming visits count.
  Stream<List<CustomerSummary>> watchCustomers({required DateTime today});

  /// One customer and their units; null once deleted.
  Stream<CustomerRecord?> watchCustomer(String id);

  /// The customer with this phone number, to avoid adding them twice.
  Future<Customer?> findByPhone(PhoneNumber phone);

  Future<Result<Customer>> addCustomer(CustomerDraft draft);

  Future<Result<void>> updateCustomer(String id, CustomerDraft draft);

  /// Deletes the customer with their units and jobs.
  Future<Result<void>> deleteCustomer(String id);

  Future<Result<void>> addUnit(String customerId, CustomerUnitDraft draft);

  Future<Result<void>> updateUnit(String id, CustomerUnitDraft draft);

  Future<Result<void>> deleteUnit(String id);
}
