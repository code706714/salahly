import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:salahly/core/theme/app_colors.dart';
import 'package:salahly/core/theme/app_spacing.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/core/time/time_labels.dart';
import 'package:salahly/core/widgets/choice_chip_button.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

/// A visit's date as picked: a day and a time, or neither while the job
/// has no date yet.
final class ScheduleChoice extends Equatable {
  const ScheduleChoice({this.day, this.time});

  /// The day and time of [scheduledAt]; nothing when it is null.
  factory ScheduleChoice.of(DateTime? scheduledAt) => scheduledAt == null
      ? none
      : ScheduleChoice(
          day: CalendarDate.of(scheduledAt),
          time: TimeOfDay.fromDateTime(scheduledAt),
        );

  /// No date yet.
  static const none = ScheduleChoice();

  /// Local midnight.
  final DateTime? day;
  final TimeOfDay? time;

  /// The moment picked; null when there is no date, or no time yet.
  DateTime? get scheduledAt {
    final day = this.day;
    final time = this.time;
    if (day == null || time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  /// A day was picked without a time, so the choice is not complete.
  bool get needsTime => day != null && time == null;

  ScheduleChoice withDay(DateTime day) =>
      ScheduleChoice(day: CalendarDate.of(day), time: time);

  /// [time] on the day picked, or on [today] when no day is picked yet.
  ScheduleChoice withTime(TimeOfDay time, {required DateTime today}) =>
      ScheduleChoice(day: day ?? CalendarDate.of(today), time: time);

  ScheduleChoice withoutTime() => ScheduleChoice(day: day);

  @override
  List<Object?> get props => [day, time];
}

/// Picks a visit's day ("النهارده", "بكره" or another) and time (four
/// usual ones or another). Tapping the picked day again clears the date.
class SchedulePicker extends StatelessWidget {
  const SchedulePicker({
    required this.value,
    required this.today,
    required this.onChanged,
    this.showsErrors = false,
    super.key,
  });

  final ScheduleChoice value;

  /// Any time on the local day the choice is relative to.
  final DateTime today;
  final ValueChanged<ScheduleChoice> onChanged;

  /// Whether to say a time is still missing.
  final bool showsErrors;

  static const _usualTimes = [
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 13, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
    TimeOfDay(hour: 19, minute: 0),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.appColors;
    final day = value.day;
    final time = value.time;
    final dayOffset = day == null ? null : CalendarDate.daysBetween(today, day);
    final isOtherDay = dayOffset != null && dayOffset != 0 && dayOffset != 1;
    final isOtherTime = time != null && !_usualTimes.contains(time);
    final usualLabels = [
      l10n.newJobTimeMorning,
      l10n.newJobTimeNoon,
      l10n.newJobTimeAfternoon,
      l10n.newJobTimeEvening,
    ];

    void pickDay(int offset) => onChanged(
      dayOffset == offset
          ? ScheduleChoice.none
          : value.withDay(
              DateTime(today.year, today.month, today.day + offset),
            ),
    );

    void pickTime(TimeOfDay picked) => onChanged(
      picked == time
          ? value.withoutTime()
          : value.withTime(picked, today: today),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            ChoiceChipButton(
              label: l10n.today,
              selected: dayOffset == 0,
              onTap: () => pickDay(0),
            ),
            ChoiceChipButton(
              label: l10n.tomorrow,
              selected: dayOffset == 1,
              onTap: () => pickDay(1),
            ),
            ChoiceChipButton(
              label: isOtherDay ? weekdayDate(day!) : l10n.newJobOtherDay,
              icon: Icons.calendar_today_outlined,
              selected: isOtherDay,
              onTap: () => _pickOtherDay(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            for (final (index, usual) in _usualTimes.indexed) ...[
              if (index > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: ChoiceChipButton(
                  label: usualLabels[index],
                  selected: usual == time,
                  padding: EdgeInsets.zero,
                  onTap: () => pickTime(usual),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: ChoiceChipButton(
            label: isOtherTime
                ? timeLabel(
                    l10n,
                    DateTime(2000, 1, 1, time.hour, time.minute),
                  )
                : l10n.newJobOtherTime,
            icon: Icons.schedule_rounded,
            selected: isOtherTime,
            onTap: () => _pickOtherTime(context),
          ),
        ),
        if (showsErrors && value.needsTime) ...[
          const SizedBox(height: 6),
          Text(
            l10n.newJobTimeRequired,
            style: TextStyle(fontSize: 13, color: colors.danger),
          ),
        ],
      ],
    );
  }

  Future<void> _pickOtherDay(BuildContext context) async {
    final start = CalendarDate.of(today);
    final picked = await showDatePicker(
      context: context,
      initialDate:
          value.day ?? DateTime(start.year, start.month, start.day + 2),
      firstDate: DateTime(start.year - 1, start.month, start.day),
      lastDate: DateTime(start.year + 2, start.month, start.day),
    );
    if (picked != null) onChanged(value.withDay(picked));
  }

  Future<void> _pickOtherTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: value.time ?? TimeOfDay.now(),
    );
    if (picked != null) onChanged(value.withTime(picked, today: today));
  }
}

/// Asks for a visit's date in a sheet, starting from [initial]. Resolves
/// to the choice made, [ScheduleChoice.none] when the technician says
/// there is no date yet, or null when dismissed.
Future<ScheduleChoice?> showSchedulePicker(
  BuildContext context, {
  DateTime? initial,
}) {
  return showModalBottomSheet<ScheduleChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ScheduleSheet(initial: ScheduleChoice.of(initial)),
  );
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.initial});

  final ScheduleChoice initial;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late ScheduleChoice _choice = widget.initial;
  var _showsErrors = false;
  final _today = DateTime.now();

  void _done() {
    if (_choice.needsTime) {
      setState(() => _showsErrors = true);
      return;
    }
    Navigator.of(context).pop(_choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.newJobScheduleTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          SchedulePicker(
            value: _choice,
            today: _today,
            showsErrors: _showsErrors,
            onChanged: (choice) => setState(() => _choice = choice),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: _done, child: Text(l10n.newJobScheduleDone)),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ScheduleChoice.none),
            child: Text(l10n.newJobNoDate),
          ),
        ],
      ),
    );
  }
}
