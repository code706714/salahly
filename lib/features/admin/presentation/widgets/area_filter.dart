import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/features/admin/domain/entities/area_coverage.dart';
import 'package:salahly/features/admin/presentation/cubit/overview_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_filters.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A drop-down of the areas the platform serves. A null area stands for
/// all of them.
///
/// The areas come from the overview's coverage, which the console loads
/// once for every page.
class AreaFilter extends StatelessWidget {
  const AreaFilter({required this.areaId, required this.onChanged, super.key});

  final String? areaId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final areas = context.select<OverviewCubit, List<AreaCoverage>>(
      (cubit) => cubit.state.coverage?.areas ?? const [],
    );
    final names = {for (final area in areas) area.id: area.name};
    return AdminDropdown<String>(
      label: l10n.adminAreaFilter,
      // An area that is not in the list yet is not offered as the value.
      value: names.containsKey(areaId) ? areaId : null,
      values: names.keys.toList(),
      labelOf: (id) => names[id] ?? id,
      allLabel: l10n.adminAllAreas,
      onChanged: onChanged,
    );
  }
}
