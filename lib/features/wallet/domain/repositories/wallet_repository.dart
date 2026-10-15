import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/balance/domain/entities/topup_method.dart';
import 'package:salahly/features/wallet/domain/entities/wallet.dart';

/// The signed-in technician's wallet.
abstract interface class WalletRepository {
  Future<Result<Wallet>> fetch();

  /// Takes [amountPiastres] out of the wallet to [account]; Salahly sends it
  /// and the amount returns if it can't.
  Future<Result<void>> requestWithdrawal({
    required int amountPiastres,
    required TopupMethod method,
    required String account,
    required String holderName,
  });
}
