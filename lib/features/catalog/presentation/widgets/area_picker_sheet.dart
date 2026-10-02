import 'package:flutter/material.dart';
import 'package:salahly/core/text/arabic_search.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/features/catalog/domain/entities/service_area.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Lets the user search and pick one area. Resolves to null if dismissed.
Future<ServiceArea?> showAreaPicker(
  BuildContext context, {
  required List<ServiceArea> areas,
}) {
  return showModalBottomSheet<ServiceArea>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _AreaPicker(areas: areas),
  );
}

class _AreaPicker extends StatefulWidget {
  const _AreaPicker({required this.areas});

  final List<ServiceArea> areas;

  @override
  State<_AreaPicker> createState() => _AreaPickerState();
}

class _AreaPickerState extends State<_AreaPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final query = foldArabic(_query);
    final matches = query.isEmpty
        ? widget.areas
        : widget.areas
              .where(
                (area) =>
                    foldArabic(area.name).contains(query) ||
                    foldArabic(area.city).contains(query),
              )
              .toList();

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.8,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                l10n.areaPickerTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: l10n.areaSearchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        l10n.areaSearchEmpty,
                        style: TextStyle(color: colors.inkMuted),
                      ),
                    )
                  : ListView.separated(
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const Divider(),
                      itemBuilder: (context, index) {
                        final area = matches[index];
                        return ListTile(
                          minTileHeight: 56,
                          title: Text(
                            area.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            area.city,
                            style: TextStyle(color: colors.inkMuted),
                          ),
                          onTap: () => Navigator.of(context).pop(area),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
