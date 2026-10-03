import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';
import 'package:salahly/features/jobs/presentation/cubit/job_details_status.dart';

export 'package:salahly/features/jobs/presentation/cubit/job_details_status.dart';

part 'quote_state.dart';

/// Writing a job's quote: its lines and how long it holds, saved as a
/// draft, sent, or marked accepted.
///
/// Edits stay on the screen until saved; the saved lines are picked up
/// again after each save so they keep their ids.
class QuoteCubit extends Cubit<QuoteState> {
  QuoteCubit({required this._jobs, required this._jobId})
    : super(const QuoteState());

  /// How long a quote can hold, in days, as the server allows.
  static const validityChoices = [1, 3, 7, 14];

  final JobsRepository _jobs;
  final String _jobId;
  StreamSubscription<JobDetails?>? _subscription;
  JobDetails? _latest;

  /// Whether the job changed while a save was running, so the saved lines
  /// are taken from it once the save is done.
  bool _changedWhileSaving = false;

  Future<void> start() async {
    _subscription = _jobs
        .watchJob(_jobId)
        .listen(_onDetails, onError: addError);
    final suggestions = await _jobs.itemSuggestions();
    if (isClosed) return;
    emit(state.copyWith(suggestions: suggestions));
  }

  void _onDetails(JobDetails? details) {
    _latest = details;
    if (details == null) {
      emit(
        state.copyWith(
          status: state.details == null
              ? JobDetailsStatus.missing
              : JobDetailsStatus.deleted,
        ),
      );
      return;
    }
    if (state.isSaving) _changedWhileSaving = true;
    emit(
      state.isDirty || state.isSaving
          ? state.copyWith(details: details)
          : _synced(details),
    );
  }

  /// The state showing [details]'s saved lines.
  QuoteState _synced(JobDetails details) => state.copyWith(
    status: JobDetailsStatus.ready,
    details: details,
    items: [
      for (final item in details.items)
        JobItemDraft(
          id: item.id,
          title: item.title,
          unitPricePiastres: item.unitPricePiastres,
          quantity: item.quantity,
        ),
    ],
    validDays: details.job.quoteValidDays,
  );

  /// Adds [item], or one more of a line with the same title and price.
  void addItem(JobItemDraft item) {
    final index = state.items.indexWhere(
      (line) =>
          line.title == item.title &&
          line.unitPricePiastres == item.unitPricePiastres,
    );
    if (index >= 0) {
      increment(index);
      return;
    }
    _edit([...state.items, item]);
  }

  void increment(int index) {
    final item = state.items[index];
    if (item.quantity >= JobItem.maxQuantity) return;
    _replace(index, item.withQuantity(item.quantity + 1));
  }

  void decrement(int index) {
    final item = state.items[index];
    if (item.quantity <= 1) return;
    _replace(index, item.withQuantity(item.quantity - 1));
  }

  void remove(int index) => _edit([...state.items]..removeAt(index));

  void setValidDays(int days) {
    if (days == state.validDays) return;
    emit(state.copyWith(validDays: days, isDirty: true));
  }

  void _replace(int index, JobItemDraft item) =>
      _edit([...state.items]..[index] = item);

  void _edit(List<JobItemDraft> items) =>
      emit(state.copyWith(items: items, isDirty: true));

  /// Saves without sending. A quote already sent or accepted keeps that
  /// status; one without lines is no quote at all.
  Future<bool> saveDraft() {
    final current = state.details?.job.quoteStatus ?? QuoteStatus.none;
    return _save(
      state.items.isEmpty
          ? QuoteStatus.none
          : current == QuoteStatus.sent || current == QuoteStatus.accepted
          ? current
          : QuoteStatus.draft,
    );
  }

  /// Saves the quote as sent, before it goes out on WhatsApp.
  Future<bool> send() async {
    if (state.items.isEmpty) return false;
    return _save(QuoteStatus.sent);
  }

  /// The customer agreed to the quote.
  Future<bool> markAccepted() async {
    if (state.items.isEmpty) return false;
    return _save(QuoteStatus.accepted);
  }

  Future<bool> _save(QuoteStatus status) async {
    if (state.isSaving || state.details == null) return false;
    _changedWhileSaving = false;
    emit(state.copyWith(isSaving: true, failure: () => null));
    final result = await _jobs.saveQuote(
      _jobId,
      items: state.items,
      validDays: state.validDays,
      status: status,
    );
    if (isClosed) return false;
    switch (result) {
      case Ok():
        final latest = _latest;
        emit(
          _changedWhileSaving && latest != null
              ? _synced(latest).copyWith(isSaving: false, isDirty: false)
              : state.copyWith(isSaving: false, isDirty: false),
        );
        return true;
      case Err(:final failure):
        emit(state.copyWith(isSaving: false, failure: () => failure));
        return false;
    }
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
