part of 'quote_cubit.dart';

final class QuoteState extends Equatable {
  const QuoteState({
    this.status = JobDetailsStatus.loading,
    this.details,
    this.items = const [],
    this.validDays = Job.defaultQuoteValidDays,
    this.suggestions = const [],
    this.isDirty = false,
    this.isSaving = false,
    this.failure,
  });

  final JobDetailsStatus status;

  /// The job as last loaded.
  final JobDetails? details;

  /// The lines on screen, saved or not.
  final List<JobItemDraft> items;
  final int validDays;

  /// Lines used in earlier jobs, most used first.
  final List<ItemSuggestion> suggestions;

  /// Something changed since the quote was last saved.
  final bool isDirty;
  final bool isSaving;

  /// Why the last save failed.
  final Failure? failure;

  int get totalPiastres =>
      items.fold(0, (sum, item) => sum + item.totalPiastres);

  QuoteState copyWith({
    JobDetailsStatus? status,
    JobDetails? details,
    List<JobItemDraft>? items,
    int? validDays,
    List<ItemSuggestion>? suggestions,
    bool? isDirty,
    bool? isSaving,
    Failure? Function()? failure,
  }) {
    return QuoteState(
      status: status ?? this.status,
      details: details ?? this.details,
      items: items ?? this.items,
      validDays: validDays ?? this.validDays,
      suggestions: suggestions ?? this.suggestions,
      isDirty: isDirty ?? this.isDirty,
      isSaving: isSaving ?? this.isSaving,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    details,
    items,
    validDays,
    suggestions,
    isDirty,
    isSaving,
    failure,
  ];
}
