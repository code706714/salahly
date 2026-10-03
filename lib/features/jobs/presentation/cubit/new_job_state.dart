part of 'new_job_cubit.dart';

enum NewJobStatus { editing, saving, saved, failed }

final class NewJobState extends Equatable {
  const NewJobState({
    required this.today,
    this.customers,
    this.customer,
    this.tags = const [],
    this.description = '',
    this.schedule = ScheduleChoice.none,
    this.sendConfirmation = true,
    this.isListening = false,
    this.showsErrors = false,
    this.status = NewJobStatus.editing,
    this.saved,
    this.failure,
  });

  /// Local midnight of the day the form was opened.
  final DateTime today;

  /// Everyone the job could be for, most recently active first; null
  /// until loaded.
  final List<Customer>? customers;

  /// Who the job is for; required to save.
  final Customer? customer;
  final List<JobTag> tags;
  final String description;
  final ScheduleChoice schedule;

  /// Whether to send the customer a WhatsApp confirmation after saving,
  /// when [canSendConfirmation].
  final bool sendConfirmation;

  /// Whether dictation is adding to [description].
  final bool isListening;

  /// Whether a save was tried with something missing, so the form says
  /// what.
  final bool showsErrors;
  final NewJobStatus status;

  /// The job as saved, once [status] is [NewJobStatus.saved].
  final Job? saved;

  /// Why saving failed, while [status] is [NewJobStatus.failed].
  final Failure? failure;

  /// A confirmation needs the customer's number and a date to confirm.
  bool get canSendConfirmation =>
      customer?.phone != null && schedule.scheduledAt != null;

  bool get sendsConfirmation => canSendConfirmation && sendConfirmation;

  bool get isComplete => customer != null && !schedule.needsTime;

  NewJobState copyWith({
    List<Customer>? customers,
    Customer? customer,
    List<JobTag>? tags,
    String? description,
    ScheduleChoice? schedule,
    bool? sendConfirmation,
    bool? isListening,
    bool? showsErrors,
  }) {
    return NewJobState(
      today: today,
      customers: customers ?? this.customers,
      customer: customer ?? this.customer,
      tags: tags ?? this.tags,
      description: description ?? this.description,
      schedule: schedule ?? this.schedule,
      sendConfirmation: sendConfirmation ?? this.sendConfirmation,
      isListening: isListening ?? this.isListening,
      showsErrors: showsErrors ?? this.showsErrors,
      status: status,
      saved: saved,
      failure: failure,
    );
  }

  NewJobState withStatus(NewJobStatus status, {Job? saved, Failure? failure}) {
    return NewJobState(
      today: today,
      customers: customers,
      customer: customer,
      tags: tags,
      description: description,
      schedule: schedule,
      sendConfirmation: sendConfirmation,
      isListening: isListening,
      showsErrors: showsErrors,
      status: status,
      saved: saved,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [
    today,
    customers,
    customer,
    tags,
    description,
    schedule,
    sendConfirmation,
    isListening,
    showsErrors,
    status,
    saved,
    failure,
  ];
}
