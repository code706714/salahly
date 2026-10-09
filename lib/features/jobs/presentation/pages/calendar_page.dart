import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_theme.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/detail_header.dart';
import 'package:salahly/features/jobs/presentation/cubit/calendar_cubit.dart';
import 'package:salahly/features/jobs/presentation/widgets/calendar_day_schedule.dart';
import 'package:salahly/features/jobs/presentation/widgets/calendar_week_strip.dart';
import 'package:salahly/features/jobs/presentation/widgets/new_job_button.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// The schedule by day.
class CalendarPage extends StatelessWidget {
  const CalendarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CalendarCubit(jobs: context.read())..start(),
      child: const CalendarView(),
    );
  }
}

class CalendarView extends StatelessWidget {
  const CalendarView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final cubit = context.read<CalendarCubit>();
    final state = context.watch<CalendarCubit>().state;
    final day = state.selectedDay;
    final month = DateFormat(
      day.year == state.today.year ? 'MMMM' : 'MMMM y',
      'ar',
    ).format(day);
    final relative = CalendarDate.daysBetween(state.today, day).abs() <= 1;

    return Scaffold(
      appBar: DetailHeader(
        title: l10n.calendarTitle(month),
        trailing: OutlinedButton(
          onPressed: cubit.showToday,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: colors.surface,
            foregroundColor: colors.ink,
            side: BorderSide(color: colors.fieldBorder, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            textStyle: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          child: Text(l10n.today),
        ),
      ),
      floatingActionButton: const NewJobButton(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarWeekStrip(
            state: state,
            onDaySelected: cubit.selectDay,
            onWeekChanged: cubit.showWeek,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 150),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Semantics(
                    header: true,
                    child: Text(
                      relative
                          ? '${weekdayDate(day)} · '
                                '${dayLabel(l10n, day, today: state.today)}'
                          : weekdayDate(day),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.inkMuted,
                      ),
                    ),
                  ),
                ),
                if (state.jobs != null)
                  CalendarDaySchedule(day: day, slots: state.slots),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
