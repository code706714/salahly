import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_radii.dart';
import 'package:salahly/core/widgets/app_card.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';
import 'package:salahly/features/admin/presentation/widgets/admin_failure_view.dart';

/// The list on the side of a review page: a header, the rows of the current
/// page, and a bar to move between pages. Says so when it is loading, empty
/// or could not load.
class QueuePanel<T> extends StatelessWidget {
  const QueuePanel({
    required this.header,
    required this.state,
    required this.rowBuilder,
    required this.emptyMessage,
    required this.onRetry,
    required this.footer,
    super.key,
  });

  /// The widest the panel gets, so the review beside it keeps its room.
  static const width = 340.0;

  final Widget header;
  final PagedState<T, Object?> state;
  final Widget Function(T item) rowBuilder;
  final String emptyMessage;
  final VoidCallback onRetry;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (state.failure case final failure? when state.items.isEmpty) {
      body = AdminFailureView(failure: failure, onRetry: onRetry);
    } else if (state.isLoading && state.items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.isEmpty) {
      body = AdminEmptyView(emptyMessage);
    } else {
      body = ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: state.items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) => rowBuilder(state.items[index]),
      );
    }
    return SizedBox(
      width: width,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 160),
              child: Opacity(
                opacity: state.isLoading && state.items.isNotEmpty ? 0.6 : 1,
                child: body,
              ),
            ),
            const SizedBox(height: 8),
            footer,
          ],
        ),
      ),
    );
  }
}

/// One row of a [QueuePanel]; the chosen one is outlined.
class QueueTile extends StatelessWidget {
  const QueueTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.divider : colors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          side: BorderSide(
            color: selected ? colors.fieldBorder : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.inkMuted,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
