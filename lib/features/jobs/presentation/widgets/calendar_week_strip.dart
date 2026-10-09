import 'dart:async';

import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/jobs/presentation/cubit/calendar_cubit.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// Seven days side by side, swiped a week at a time. Days with visits
/// carry a dot; the open day is filled.
class CalendarWeekStrip extends StatefulWidget {
  const CalendarWeekStrip({
    required this.state,
    required this.onDaySelected,
    required this.onWeekChanged,
    super.key,
  });

  final CalendarState state;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<int> onWeekChanged;

  @override
  State<CalendarWeekStrip> createState() => _CalendarWeekStripState();
}

class _CalendarWeekStripState extends State<CalendarWeekStrip> {
  /// The page of week 0, far enough in to swipe back through past weeks.
  static const _origin = 5200;

  late final _pages = PageController(initialPage: _origin + widget.state.week);

  @override
  void didUpdateWidget(CalendarWeekStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final page = _origin + widget.state.week;
    if (!_pages.hasClients || _pages.page?.round() == page) return;
    // A neighbouring week slides in; a jump back to today is instant.
    if ((widget.state.week - oldWidget.state.week).abs() == 1) {
      unawaited(
        _pages.animateToPage(
          page,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    } else {
      _pages.jumpToPage(page);
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(
          height: 72,
          child: PageView.builder(
            controller: _pages,
            onPageChanged: (page) => widget.onWeekChanged(page - _origin),
            itemBuilder: (context, page) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _Week(
                state: widget.state,
                week: page - _origin,
                onDaySelected: widget.onDaySelected,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Week extends StatelessWidget {
  const _Week({
    required this.state,
    required this.week,
    required this.onDaySelected,
  });

  final CalendarState state;
  final int week;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final origin = state.origin;
    final isShown = week == state.week;
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: _Day(
              day: DateTime(
                origin.year,
                origin.month,
                origin.day + 7 * week + i,
              ),
              state: state,
              // Dots are only known for the week the schedule shows.
              showsDot: isShown,
              onTap: onDaySelected,
            ),
          ),
        ],
      ],
    );
  }
}

class _Day extends StatelessWidget {
  const _Day({
    required this.day,
    required this.state,
    required this.showsDot,
    required this.onTap,
  });

  final DateTime day;
  final CalendarState state;
  final bool showsDot;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selected = day == state.selectedDay;
    final foreground = selected
        ? colors.background
        : day.isBefore(state.today)
        ? colors.inkMuted
        : colors.ink;
    final name = weekdayShortName(AppLocalizations.of(context), day.weekday);
    return Semantics(
      button: true,
      selected: selected,
      label: '$name ${day.day}',
      excludeSemantics: true,
      child: Material(
        color: selected ? colors.ink : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onTap(day),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                name,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                  color: foreground,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: showsDot && state.hasJobsOn(day)
                      ? colors.primary
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
