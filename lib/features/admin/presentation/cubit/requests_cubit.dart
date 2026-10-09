import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_request.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/repositories/requests_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';

/// The customers' requests, newest first.
class RequestsCubit extends PagedCubit<AdminRequest, RequestFilter> {
  RequestsCubit(this._repository) : super(const RequestFilter());

  final RequestsRepository _repository;

  @override
  Future<Result<PagedResult<AdminRequest>>> fetch(
    RequestFilter filter, {
    required int limit,
    required int offset,
  }) => _repository.fetchRequests(filter, limit: limit, offset: offset);
}
