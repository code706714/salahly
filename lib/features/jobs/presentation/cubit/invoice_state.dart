part of 'invoice_cubit.dart';

/// The invoice could not be written or shared as a PDF.
final class InvoicePdfFailure extends Failure {
  const InvoicePdfFailure();
}

/// Money the technician just recorded on this screen.
final class RecordedPayment extends Equatable {
  const RecordedPayment({
    required this.amountPiastres,
    required this.method,
    required this.balancePiastres,
  });

  final int amountPiastres;
  final PaymentMethod method;

  /// What the customer still owes after it.
  final int balancePiastres;

  @override
  List<Object?> get props => [amountPiastres, method, balancePiastres];
}

final class InvoiceState extends Equatable {
  const InvoiceState({
    required this.today,
    this.status = JobDetailsStatus.loading,
    this.details,
    this.isRecording = false,
    this.recorded,
    this.isSharing = false,
    this.failure,
  });

  /// When the screen opened, to date the invoice and name promised days.
  final DateTime today;
  final JobDetailsStatus status;
  final JobDetails? details;
  final bool isRecording;

  /// The payment recorded on this screen, if any.
  final RecordedPayment? recorded;
  final bool isSharing;

  /// Why the last action failed.
  final Failure? failure;

  InvoiceState copyWith({
    JobDetailsStatus? status,
    JobDetails? Function()? details,
    bool? isRecording,
    RecordedPayment? Function()? recorded,
    bool? isSharing,
    Failure? Function()? failure,
  }) {
    return InvoiceState(
      today: today,
      status: status ?? this.status,
      details: details != null ? details() : this.details,
      isRecording: isRecording ?? this.isRecording,
      recorded: recorded != null ? recorded() : this.recorded,
      isSharing: isSharing ?? this.isSharing,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    today,
    status,
    details,
    isRecording,
    recorded,
    isSharing,
    failure,
  ];
}
