import 'package:flutter/material.dart';

/// Asking for a technician: the problem, photos, the address and the time.
///
/// Starts on [categoryId] when given; [technicianId] sends the request to
/// that technician first.
class NewRequestPage extends StatelessWidget {
  const NewRequestPage({this.categoryId, this.technicianId, super.key});

  final String? categoryId;
  final String? technicianId;

  @override
  Widget build(BuildContext context) => const Scaffold();
}
