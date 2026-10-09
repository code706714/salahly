import 'package:flutter/material.dart';

/// The icon of a trade; a wrench for one this version doesn't know.
IconData categoryIcon(String? categoryId) => switch (categoryId) {
  'ac' => Icons.ac_unit_rounded,
  'plumbing' => Icons.water_drop_outlined,
  'electrical' => Icons.bolt_rounded,
  'washing_machines' => Icons.local_laundry_service_outlined,
  'refrigerators' => Icons.kitchen_outlined,
  _ => Icons.handyman_outlined,
};
