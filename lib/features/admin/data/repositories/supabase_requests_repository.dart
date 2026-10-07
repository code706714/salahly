import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/data/models/request_models.dart';
import 'package:salahly/features/admin/data/repositories/admin_rpc.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/repositories/requests_repository.dart';
import 'package:salahly/features/marketplace/data/models/wire.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRequestsRepository implements RequestsRepository {
  SupabaseRequestsRepository(SupabaseClient client) : _rpc = AdminRpc(client);

  final AdminRpc _rpc;

  @override
  Future<Result<PagedResult<AdminRequest>>> fetchRequests(
    RequestFilter filter, {
    required int limit,
    required int offset,
  }) => _rpc.call('admin_list_requests', {
    'p_search': _searchOf(filter.search),
    'p_area_id': filter.areaId,
    'p_status': filter.status == null ? null : toWire(filter.status!),
    'p_days': filter.days,
    'p_limit': limit,
    'p_offset': offset,
  }, RequestModels.requests);

  @override
  Future<Result<PagedResult<AdminComplaint>>> fetchComplaints(
    ComplaintFilter filter, {
    required int limit,
    required int offset,
  }) => _rpc.call('admin_list_complaints', {
    'p_status': filter.name,
    'p_limit': limit,
    'p_offset': offset,
  }, RequestModels.complaints);

  @override
  Future<Result<void>> resolveComplaint(String complaintId, String note) =>
      _rpc.run('admin_resolve_complaint', {
        'p_complaint_id': complaintId,
        'p_note': note,
      });

  /// An empty search box means no search.
  static String? _searchOf(String text) {
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
