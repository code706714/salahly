import 'package:flutter/material.dart';

/// Adds or edits a customer. STUB: replaced in milestone 2.
class CustomerFormPage extends StatelessWidget {
  const CustomerFormPage({
    this.customerId,
    this.fromContacts = false,
    super.key,
  });

  final String? customerId;
  final bool fromContacts;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('CustomerFormPage')));
}
