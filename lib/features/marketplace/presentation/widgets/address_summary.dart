import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/catalog/presentation/cubit/areas_cubit.dart';
import 'package:salahly/features/marketplace/domain/entities/consumer_address.dart';

/// A saved address in two lines: its label, then the details and the area.
class AddressSummary extends StatelessWidget {
  const AddressSummary({required this.address, super.key});

  final ConsumerAddress address;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final area = context.select<AreasCubit, String?>(
      (cubit) => cubit.state.nameOf(address.areaId),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          address.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.5,
            color: colors.ink,
          ),
        ),
        Text(
          [address.details, ?area].join('، '),
          style: TextStyle(fontSize: 15, height: 1.5, color: colors.inkMuted),
        ),
      ],
    );
  }
}
