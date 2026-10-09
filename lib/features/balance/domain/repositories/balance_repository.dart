import 'package:salahly/core/error/result.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/balance/domain/entities/credit_pack.dart';
import 'package:salahly/features/balance/domain/entities/ledger_entry.dart';
import 'package:salahly/features/balance/domain/entities/payment_account.dart';
import 'package:salahly/features/balance/domain/entities/topup.dart';

/// Buying uses by transfer, and the record of the balance. Approving a
/// transfer happens outside the app.
abstract interface class BalanceRepository {
  /// The packs on sale to [role], cheapest first.
  Future<Result<List<CreditPack>>> fetchPacks(UserRole role);

  /// Where money can be sent, one account per method.
  Future<Result<List<PaymentAccount>>> fetchPaymentAccounts();

  /// The latest transfers of [role], newest first.
  Future<Result<List<Topup>>> fetchTopups(UserRole role);

  /// The latest movements of the [role]'s balance, newest first.
  Future<Result<List<LedgerEntry>>> fetchLedger(UserRole role);

  /// Uploads the transfer's screenshot, which `PhotoPicker` already
  /// cleaned, and returns its stored path.
  Future<Result<String>> uploadScreenshot(String localPath);

  /// Says a transfer of [packId] was made from [senderAccount]; returns
  /// the transfer's id. The server decides the uses, and refuses with a
  /// `PriceChangedFailure` when the pack no longer costs
  /// [expectedPricePiastres], what the person saw and transferred.
  Future<Result<String>> submitTopup({
    required String packId,
    required int expectedPricePiastres,
    required TopupMethod method,
    required String senderAccount,
    required String screenshotPath,
  });
}
