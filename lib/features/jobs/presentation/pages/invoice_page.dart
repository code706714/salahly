import 'package:flutter/material.dart';

/// A job's invoice and payments. STUB: replaced in milestone 2.
class InvoicePage extends StatelessWidget {
  const InvoicePage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('InvoicePage')));
}
