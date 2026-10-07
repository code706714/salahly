import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// "8 من 142" with buttons for the next and the previous page of a list.
class PagerBar extends StatelessWidget {
  const PagerBar({
    required this.page,
    required this.pageCount,
    required this.summary,
    required this.onPage,
    super.key,
  });

  /// Builds the bar for a [PagedState], with [summary] saying how many rows
  /// of how many it shows.
  PagerBar.of(
    PagedState<Object?, Object?> state, {
    required String Function(int shown, int total) summary,
    required ValueChanged<int> onPage,
    Key? key,
  }) : this(
         page: state.page,
         pageCount: state.pageCount,
         summary: summary(state.items.length, state.total),
         onPage: onPage,
         key: key,
       );

  final int page;
  final int pageCount;
  final String summary;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    return Row(
      children: [
        Text(
          summary,
          style: TextStyle(fontSize: 14, color: colors.inkMuted),
        ),
        const Spacer(),
        if (pageCount > 1) ...[
          TextButton(
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            child: Text(l10n.adminPreviousPage),
          ),
          Text(
            l10n.adminPageIndicator(page + 1, pageCount),
            style: TextStyle(fontSize: 14, color: colors.inkMuted),
          ),
          TextButton(
            onPressed: page + 1 < pageCount ? () => onPage(page + 1) : null,
            child: Text(l10n.adminNextPage),
          ),
        ],
      ],
    );
  }
}
