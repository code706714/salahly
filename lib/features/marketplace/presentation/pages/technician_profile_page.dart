import 'package:flutter/material.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';

/// A technician's public profile: ratings, areas, prices and reviews.
///
/// Opened from [offer], it offers picking it and pops `true` when picked;
/// otherwise it offers sending this technician a new request.
class TechnicianProfilePage extends StatelessWidget {
  const TechnicianProfilePage({
    required this.technicianId,
    this.offer,
    super.key,
  });

  final String technicianId;
  final RequestOffer? offer;

  @override
  Widget build(BuildContext context) => const Scaffold();
}
