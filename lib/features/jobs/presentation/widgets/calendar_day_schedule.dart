import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:salahly/core/router/app_routes.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/time/part_of_day.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/presentation/cubit/calendar_cubit.dart';
import 'package:salahly/features/jobs/presentation/job_labels.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// One day hour by hour. A visit opens its job; an empty hour starts a new
/// job at that time.
class CalendarDaySchedule extends StatelessWidget {
  const CalendarDaySchedule({
    required this.day,
    required this.slots,
    super.key,
  });

  /// Local midnight.
  final DateTime day;
  final List<CalendarSlot> slots;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in slots) _Slot(day: day, slot: slot),
      ],
    );
  }
}

class _Slot extends StatelessWidget {
  const _Slot({required this.day, required this.slot});

  final DateTime day;
  final CalendarSlot slot;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final at = DateTime(day.year, day.month, day.day, slot.hour);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              hourLabel(l10n, slot.hour),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: colors.inkMuted,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: slot.jobs.isEmpty
                  ? Semantics(
                      button: true,
                      label: l10n.calendarNewJobAt(timeLabel(l10n, at)),
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push(AppRoutes.newJobAt(at)),
                        child: const SizedBox(height: 48),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (index, summary) in slot.jobs.indexed) ...[
                          if (index > 0) const SizedBox(height: 4),
                          _Visit(summary: summary),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Visit extends StatelessWidget {
  const _Visit({required this.summary});

  final JobSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final job = summary.job;
    final at = job.scheduledAt!;
    final (background, bar) = switch (job.status) {
      JobStatus.unconfirmed => (colors.primarySoft, colors.primary),
      _ when job.source == JobSource.platform && job.status.isOpen => (
        colors.inkSoft,
        colors.ink,
      ),
      _ => (colors.successSoft, colors.successBright),
    };
    final name = job.source == JobSource.platform
        ? '${summary.customerName} · ${l10n.jobFromPlatform}'
        : summary.customerName;
    final details = [
      if (at.minute != 0) clockTime(at),
      jobTitle(l10n, job),
      visitLength(l10n, job.durationMinutes),
    ].join(' · ');

    final visit = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Material(
        color: background,
        child: InkWell(
          onTap: () => context.push(AppRoutes.job(job.id)),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: colors.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: 4,
                child: ColoredBox(color: bar),
              ),
            ],
          ),
        ),
      ),
    );
    return job.status.isDone ? Opacity(opacity: 0.85, child: visit) : visit;
  }
}

/// An hour of the day as the schedule labels it: "9 ص", "12 ض", "4 ع",
/// "7 م".
String hourLabel(AppLocalizations l10n, int hour) {
  final dial = hour % 12 == 0 ? 12 : hour % 12;
  return switch (PartOfDay.of(DateTime(2000, 1, 1, hour))) {
    PartOfDay.morning => l10n.calendarHourMorning(dial),
    PartOfDay.noon => l10n.calendarHourNoon(dial),
    PartOfDay.afternoon => l10n.calendarHourAfternoon(dial),
    PartOfDay.sunset => l10n.calendarHourEvening(dial),
    PartOfDay.night =>
      hour < 12
          ? l10n.calendarHourMorning(dial)
          : l10n.calendarHourEvening(dial),
  };
}

/// How long a visit takes, the way it is said: "ساعة", "ساعة ونص",
/// "3 ساعات", "45 دقيقة".
String visitLength(AppLocalizations l10n, int minutes) {
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 30) return l10n.calendarHoursAndHalf(hours);
  if (hours == 0) return l10n.calendarMinutes(rest);
  if (rest == 0) return l10n.calendarHours(hours);
  return l10n.calendarHoursAndMinutes(
    l10n.calendarHours(hours),
    l10n.calendarMinutes(rest),
  );
}
