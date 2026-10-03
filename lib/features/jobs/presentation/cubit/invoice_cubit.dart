import 'dart:async';
import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/launch/external_apps.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/time/calendar_date.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';
import 'package:salahly/features/jobs/domain/repositories/jobs_repository.dart';
import 'package:salahly/features/jobs/presentation/cubit/job_details_status.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_labels.dart';
import 'package:salahly/features/jobs/presentation/invoice/invoice_pdf.dart';
import 'package:salahly/l10n/generated/app_localizations.dart';

export 'package:salahly/features/jobs/presentation/cubit/job_details_status.dart';

part 'invoice_state.dart';

/// A job's invoice: numbering it, recording the money received and the
/// day the customer promised to pay, and sharing it as a PDF.
class InvoiceCubit extends Cubit<InvoiceState> {
  InvoiceCubit({
    required this._jobs,
    required this._apps,
    required this._jobId,
    this._pdf = const InvoicePdf(),
    this._temporaryDirectory = getTemporaryDirectory,
    DateTime Function() clock = DateTime.now,
  }) : super(InvoiceState(today: clock()));

  final JobsRepository _jobs;
  final ExternalApps _apps;
  final String _jobId;
  final InvoicePdf _pdf;
  final Future<Directory> Function() _temporaryDirectory;
  StreamSubscription<JobDetails?>? _subscription;
  bool _numbering = false;

  void start() {
    _subscription = _jobs
        .watchJob(_jobId)
        .listen(_onDetails, onError: addError);
  }

  void _onDetails(JobDetails? details) {
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
    emit(
      state.copyWith(status: JobDetailsStatus.ready, details: () => details),
    );
    // A job is numbered once there is something to bill.
    if (!_numbering &&
        details.items.isNotEmpty &&
        details.job.invoiceNumber == null) {
      _numbering = true;
      unawaited(_number());
    }
  }

  Future<void> _number() async {
    final result = await _jobs.issueInvoice(_jobId);
    if (isClosed) return;
    if (result case Err(:final failure)) {
      // Tried again with the job's next change.
      _numbering = false;
      emit(state.copyWith(failure: () => failure));
    }
  }

  /// Records [amountPiastres] received by [method]; it must be between
  /// one piastre and what is still owed. Returns whether it was saved.
  Future<bool> recordPayment({
    required int amountPiastres,
    required PaymentMethod method,
  }) async {
    final balance = state.details?.balancePiastres ?? 0;
    if (state.isRecording || amountPiastres < 1 || amountPiastres > balance) {
      return false;
    }
    emit(state.copyWith(isRecording: true, failure: () => null));
    final result = await _jobs.recordPayment(
      _jobId,
      amountPiastres: amountPiastres,
      method: method,
    );
    if (isClosed) return false;
    switch (result) {
      case Ok():
        emit(
          state.copyWith(
            isRecording: false,
            recorded: () => RecordedPayment(
              amountPiastres: amountPiastres,
              method: method,
              balancePiastres: balance - amountPiastres,
            ),
          ),
        );
        return true;
      case Err(:final failure):
        emit(state.copyWith(isRecording: false, failure: () => failure));
        return false;
    }
  }

  /// The day the customer promised to pay, or null to forget the promise.
  Future<void> setPaymentPromise(DateTime? day) async {
    emit(state.copyWith(failure: () => null));
    final result = await _jobs.setPaymentPromise(
      _jobId,
      day == null ? null : CalendarDate.of(day),
    );
    if (isClosed) return;
    if (result case Err(:final failure)) {
      emit(state.copyWith(failure: () => failure));
    }
  }

  /// Writes the invoice as a PDF and opens the share sheet with it.
  Future<void> sharePdf(
    AppLocalizations l10n, {
    required String technicianName,
    required PhoneNumber? technicianPhone,
    String? place,
  }) async {
    final details = state.details;
    if (details == null || state.isSharing) return;
    emit(state.copyWith(isSharing: true, failure: () => null));
    final number = details.job.invoiceNumber;
    final label = number == null ? null : invoiceNumberLabel(number);
    bool shared;
    try {
      final bytes = await _pdf.build(
        l10n,
        details: details,
        technicianName: technicianName,
        technicianPhone: technicianPhone,
        issuedOn: details.job.finishedAt ?? state.today,
        place: place,
      );
      final directory = await _temporaryDirectory();
      final file = File('${directory.path}/invoice-${label ?? _jobId}.pdf');
      await file.writeAsBytes(bytes, flush: true);
      shared = await _apps.shareFile(
        file.path,
        name: label == null
            ? '${l10n.invoiceTitleUnnumbered}.pdf'
            : l10n.invoicePdfName(label),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      shared = false;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        isSharing: false,
        failure: shared ? null : () => const InvoicePdfFailure(),
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
