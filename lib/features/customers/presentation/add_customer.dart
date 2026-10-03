import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';

/// Opens the customer form at [location] and then the customer it closes
/// with: the one just added, or the one who already had that number.
Future<void> addCustomer(BuildContext context, String location) async {
  final customer = await context.push<Customer>(location);
  if (customer != null && context.mounted) {
    await context.push(AppRoutes.customer(customer.id));
  }
}
