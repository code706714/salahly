import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';

/// A row of [AdminTable]: one widget per column, and a tint when the row
/// needs a second look.
class AdminTableRow {
  const AdminTableRow({required this.cells, this.background});

  final List<Widget> cells;
  final Color? background;
}

/// A plain table: column titles, then rows separated by thin lines. Each
/// column takes a share of the width given by [flexes].
class AdminTable extends StatelessWidget {
  const AdminTable({
    required this.headers,
    required this.flexes,
    required this.rows,
    super.key,
  }) : assert(
         headers.length == flexes.length,
         'A title and a width for every column',
       );

  final List<String> headers;
  final List<int> flexes;
  final List<AdminTableRow> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                for (var i = 0; i < headers.length; i++)
                  Expanded(
                    flex: flexes[i],
                    child: Text(
                      headers[i],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.inkMuted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (final row in rows)
          DecoratedBox(
            decoration: BoxDecoration(
              color: row.background,
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Row(
                children: [
                  for (var i = 0; i < row.cells.length; i++)
                    Expanded(
                      flex: flexes[i],
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: DefaultTextStyle.merge(
                          style: const TextStyle(fontSize: 14),
                          child: row.cells[i],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
