import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';

/// The frame of a console page: a title with an optional line under it and
/// controls on the other side, then the content, in a column no wider than
/// the design's.
class AdminPage extends StatelessWidget {
  const AdminPage({
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.scrollable = true,
    super.key,
  });

  /// The widest the content gets, so lines stay readable on a big screen.
  static const maxWidth = 1240.0;

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  /// Whether the page scrolls as a whole. A page that scrolls inside its
  /// own panels turns this off.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final textTheme = Theme.of(context).textTheme;
    final header = Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: textTheme.headlineSmall),
            if (subtitle != null)
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(color: colors.inkMuted),
              ),
          ],
        ),
        ?trailing,
      ],
    );
    final body = Padding(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [header, const SizedBox(height: 20), child],
        ),
      ),
    );
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: scrollable ? SingleChildScrollView(child: body) : body,
    );
  }
}
