import 'package:flutter/material.dart';

/// One customer. STUB: replaced in milestone 2.
class CustomerPage extends StatelessWidget {
  const CustomerPage({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('CustomerPage')));
}
