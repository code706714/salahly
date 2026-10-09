import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/jobs/domain/entities/job.dart';
import 'package:salahly/features/jobs/domain/entities/job_details.dart';
import 'package:salahly/features/jobs/domain/entities/job_item.dart';
import 'package:salahly/features/jobs/domain/entities/job_photo.dart';
import 'package:salahly/features/jobs/domain/entities/job_summary.dart';
import 'package:salahly/features/jobs/domain/entities/month_income.dart';
import 'package:salahly/features/jobs/domain/entities/payment.dart';

/// The technician's jobs, kept on the phone and synced in the background.
/// Writes succeed offline.
abstract interface class JobsRepository {
  /// Jobs scheduled in [from, to), soonest first; cancelled ones excluded.
  Stream<List<JobSummary>> watchScheduled({
    required DateTime from,
    required DateTime to,
  });

  /// Jobs still ahead (not finished or cancelled), soonest first, then
  /// those without a date.
  Stream<List<JobSummary>> watchOpen();

  /// Finished jobs the customer has not fully paid, oldest first.
  Stream<List<JobSummary>> watchAwaitingPayment();

  /// Done jobs with nothing left to collect (paid, or finished with no
  /// money owed) and cancelled ones, most recent first.
  Stream<List<JobSummary>> watchClosed({int limit = 100});

  /// One customer's jobs, most recent first.
  Stream<List<JobSummary>> watchCustomerJobs(String customerId);

  /// Whether any job was ever recorded, to tell a first day from a quiet one.
  Stream<bool> watchHasJobs();

  /// One job with its lines, payments and photos; null once deleted.
  Stream<JobDetails?> watchJob(String id);

  /// Jobs finished in [month]'s calendar month (local time).
  Stream<MonthIncome> watchMonthIncome(DateTime month);

  /// When the earliest job counted by [watchMonthIncome] was finished
  /// (local time); null while no job is finished.
  Stream<DateTime?> watchFirstFinishedAt();

  /// Lines used in earlier jobs, most used first.
  Future<List<ItemSuggestion>> itemSuggestions();

  /// Saves a new job and returns its id.
  Future<Result<String>> createJob(JobDraft draft);

  Future<Result<void>> reschedule(
    String id, {
    required DateTime? scheduledAt,
    required int durationMinutes,
  });

  /// Moves the job to its next status. Returns the job as it was, so the
  /// move can be undone with [restore].
  Future<Result<Job>> advance(String id);

  /// Puts a job back the way it was before [advance] or [cancel].
  Future<Result<void>> restore(Job previous);

  /// Returns the job as it was, for [restore].
  Future<Result<Job>> cancel(String id);

  Future<Result<void>> deleteJob(String id);

  /// Replaces the job's lines with [items], in that order.
  Future<Result<void>> saveQuote(
    String jobId, {
    required List<JobItemDraft> items,
    required int validDays,
    required QuoteStatus status,
  });

  /// Gives the job an invoice number if it has none yet and returns it.
  Future<Result<int>> issueInvoice(String jobId);

  /// Records money received. A finished job that is now fully paid
  /// becomes paid.
  Future<Result<void>> recordPayment(
    String jobId, {
    required int amountPiastres,
    required PaymentMethod method,
  });

  Future<Result<void>> setPaymentPromise(String jobId, DateTime? day);

  /// Keeps the photo at [pickedPath] and uploads it when online.
  Future<Result<void>> addPhoto(
    String jobId, {
    required PhotoKind kind,
    required String pickedPath,
  });

  Future<Result<void>> deletePhoto(String photoId);
}
