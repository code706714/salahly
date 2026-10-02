import 'package:flutter/material.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A job's time over its part of the day: "1:00" above "الضهر".
class JobTime extends StatelessWidget {
  const JobTime({
    required this.time,
    required this.color,
    this.width = 56,
    this.fontSize = 18,
    super.key,
  });

  final DateTime time;
  final Color color;
  final double width;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: width,
      child: Column(
        children: [
          Text(
            clockTime(time),
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: color,
            ),
          ),
          Text(
            partOfDayLabel(l10n, PartOfDay.of(time)),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              height: 1.4,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
