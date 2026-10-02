import 'package:flutter/material.dart';

/// A job's quote. STUB: replaced in milestone 2.
class QuotePage extends StatelessWidget {
  const QuotePage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('QuotePage')));
}
