import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/admin/domain/entities/admin_complaint.dart';
import 'package:salahly/features/admin/domain/entities/paged_result.dart';
import 'package:salahly/features/admin/domain/repositories/requests_repository.dart';
import 'package:salahly/features/admin/domain/repositories/users_repository.dart';
import 'package:salahly/features/admin/presentation/cubit/action_cubit.dart';
import 'package:salahly/features/admin/presentation/cubit/paged_cubit.dart';

/// Customers' complaints about technicians, newest first; the open ones by
/// default.
class ComplaintsCubit extends PagedCubit<AdminComplaint, ComplaintFilter> {
  ComplaintsCubit(this._repository) : super(ComplaintFilter.open);

  final RequestsRepository _repository;

  @override
  Future<Result<PagedResult<AdminComplaint>>> fetch(
    ComplaintFilter filter, {
    required int limit,
    required int offset,
  }) => _repository.fetchComplaints(filter, limit: limit, offset: offset);
}

/// What the team does about a complaint: closes it, or suspends the
/// technician it is about.
class ComplaintActionsCubit extends ActionCubit {
  ComplaintActionsCubit({
    required this._requestsRepository,
    required this._usersRepository,
  });

  final RequestsRepository _requestsRepository;
  final UsersRepository _usersRepository;

  /// [note] is 3 to 500 characters.
  Future<void> resolve(String complaintId, String note) => perform(
    () => _requestsRepository.resolveComplaint(complaintId, note),
    outcome: AdminOutcome.complaintResolved,
  );

  /// [reason] is 3 to 200 characters kept for the team.
  Future<void> suspendTechnician(String technicianId, String reason) => perform(
    () => _usersRepository.suspend(technicianId, reason),
    outcome: AdminOutcome.userSuspended,
  );
}
