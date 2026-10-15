import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/escrow/domain/entities/escrow.dart';

/// The guaranteed payment of a request, from both sides.
abstract interface class EscrowRepository {
  /// The consumer's view; null when the request isn't hers.
  Future<Result<EscrowInfo?>> fetchInfo(String requestId);

  /// The work is right: the money goes to the technician.
  Future<Result<void>> confirmWork(String requestId);

  /// Something is wrong: the money stays with Salahly until it decides.
  Future<Result<void>> dispute(String requestId, String reason);

  /// The technician's view; null when there is no live payment.
  Future<Result<TechnicianEscrow?>> fetchTechnicianEscrow(String requestId);

  /// Where Salahly pays the signed-in technician; null before he sets it.
  Future<Result<PayoutAccount?>> fetchPayoutAccount();

  Future<Result<void>> savePayoutAccount(PayoutAccount account);
}
