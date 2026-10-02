import 'package:flutter/material.dart';

/// One job. STUB: replaced in milestone 2.
class JobPage extends StatelessWidget {
  const JobPage({required this.jobId, super.key});

  final String jobId;

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('JobPage')));
}
