import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/speech/speech_input.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/repositories/customers_repository.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';
import 'package:salahly/features/jobs/presentation/widgets/schedule_picker.dart';

part 'new_job_state.dart';

/// Records a new job: who it is for, the problem (typed or said) and
/// when, if known yet. Saving works offline.
class NewJobCubit extends Cubit<NewJobState> {
  NewJobCubit({
    required this._jobs,
    required this._customers,
    required this._speech,
    this._customerId,
    DateTime? scheduledAt,
    this._clock = DateTime.now,
  }) : super(
         NewJobState(
           today: CalendarDate.of(_clock()),
           schedule: ScheduleChoice.of(scheduledAt),
         ),
       );

  final JobsRepository _jobs;
  final CustomersRepository _customers;
  final SpeechInput _speech;
  final DateTime Function() _clock;

  /// The customer to start with, when the form was opened for one.
  final String? _customerId;

  final _subscriptions = <StreamSubscription<Object?>>[];

  void start() {
    _subscriptions.add(
      _customers
          .watchCustomers(today: state.today)
          .listen(
            (summaries) => emit(
              state.copyWith(
                customers: [for (final summary in summaries) summary.customer],
              ),
            ),
            onError: addError,
          ),
    );
    final customerId = _customerId;
    if (customerId != null) {
      _subscriptions.add(
        _customers.watchCustomer(customerId).take(1).listen((record) {
          if (record != null && state.customer == null) {
            emit(state.copyWith(customer: record.customer));
          }
        }, onError: addError),
      );
    }
  }

  void selectCustomer(Customer customer) =>
      emit(state.copyWith(customer: customer));

  void toggleTag(JobTag tag) {
    final tags = state.tags.contains(tag)
        ? [
            for (final picked in state.tags)
              if (picked != tag) picked,
          ]
        : [...state.tags, tag];
    emit(state.copyWith(tags: tags));
  }

  /// The description as typed. Typing takes over from dictation.
  void editDescription(String text) {
    final wasListening = state.isListening;
    emit(state.copyWith(description: text, isListening: false));
    if (wasListening) unawaited(_speech.stop());
  }

  /// Starts dictation, adding what is said after what is written, or
  /// stops it. Returns false when the phone cannot take dictation.
  Future<bool> toggleListening() async {
    if (state.isListening) {
      await stopListening();
      return true;
    }
    final written = state.description.trimRight();
    emit(state.copyWith(isListening: true));
    final listening = await _speech.listen(
      onWords: (words) {
        if (isClosed || !state.isListening) return;
        final heard = words.trim();
        final text = [
          if (written.isNotEmpty) written,
          if (heard.isNotEmpty) heard,
        ].join(' ');
        emit(
          state.copyWith(
            description: text.length > Job.maxDescriptionLength
                ? text.substring(0, Job.maxDescriptionLength)
                : text,
          ),
        );
      },
    );
    if (!listening && !isClosed) emit(state.copyWith(isListening: false));
    return listening;
  }

  Future<void> stopListening() async {
    if (!state.isListening) return;
    emit(state.copyWith(isListening: false));
    await _speech.stop();
  }

  void changeSchedule(ScheduleChoice schedule) =>
      emit(state.copyWith(schedule: schedule));

  void setSendConfirmation({required bool send}) =>
      emit(state.copyWith(sendConfirmation: send));

  /// Saves the job, or marks what is missing. Once saved, the state holds
  /// the job for the confirmation message and its page.
  Future<void> save() async {
    if (state.status == NewJobStatus.saving ||
        state.status == NewJobStatus.saved) {
      return;
    }
    final customer = state.customer;
    if (customer == null || !state.isComplete) {
      emit(state.copyWith(showsErrors: true));
      return;
    }
    emit(state.withStatus(NewJobStatus.saving));
    await stopListening();
    final draft = JobDraft(
      customerId: customer.id,
      tags: [
        for (final tag in JobTag.values)
          if (state.tags.contains(tag)) tag,
      ],
      description: state.description,
      scheduledAt: state.schedule.scheduledAt,
    );
    final result = await _jobs.createJob(draft);
    if (isClosed) return;
    switch (result) {
      case Ok(:final value):
        final now = _clock();
        emit(
          state.withStatus(
            NewJobStatus.saved,
            saved: Job(
              id: value,
              customerId: draft.customerId,
              tags: draft.tags,
              description: draft.description,
              scheduledAt: draft.scheduledAt,
              createdAt: now,
              updatedAt: now,
            ),
          ),
        );
      case Err(:final failure):
        emit(state.withStatus(NewJobStatus.failed, failure: failure));
    }
  }

  @override
  Future<void> close() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    if (state.isListening) await _speech.stop();
    return super.close();
  }
}
