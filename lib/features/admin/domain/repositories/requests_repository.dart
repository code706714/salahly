import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';

abstract interface class RequestsRepository {
  Future<Result<PagedResult<AdminRequest>>> fetchRequests(
    RequestFilter filter, {
    required int limit,
    required int offset,
  });

  Future<Result<PagedResult<AdminComplaint>>> fetchComplaints(
    ComplaintFilter filter, {
    required int limit,
    required int offset,
  });

  /// [note] is 3 to 500 characters.
  Future<Result<void>> resolveComplaint(String complaintId, String note);
}
