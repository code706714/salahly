part of 'withdraw_cubit.dart';

enum WithdrawStatus { loading, failed, editing, sending, sent }

final class WithdrawState extends Equatable {
  const WithdrawState({
    this.status = WithdrawStatus.loading,
    this.balancePiastres = 0,
    this.minPiastres = 0,
    this.method = TopupMethod.wallet,
    this.amount = '',
    this.account = '',
    this.holder = '',
    this.failure,
  });

  final WithdrawStatus status;
  final int balancePiastres;
  final int minPiastres;
  final TopupMethod method;

  /// The pounds, as typed.
  final String amount;

  /// The wallet number or InstaPay address, as typed.
  final String account;

  /// The name on the account, as typed.
  final String holder;
  final Failure? failure;

  /// The amount in piastres, or null while it is not a number between the
  /// smallest withdrawal and the balance.
  int? get validAmount {
    final piastres = parsePounds(amount);
    return piastres != null &&
            piastres >= minPiastres &&
            piastres <= balancePiastres
        ? piastres
        : null;
  }

  /// The account as the server takes it, or null while it is not valid.
  String? get validAccount => normalizedSender(method, account);

  String? get validHolder {
    final name = holder.trim().replaceAll(RegExp(r'\s+'), ' ');
    return name.length >= 2 && name.length <= 80 ? name : null;
  }

  bool get canSend =>
      status == WithdrawStatus.editing &&
      validAmount != null &&
      validAccount != null &&
      validHolder != null;

  WithdrawState copyWith({
    WithdrawStatus? status,
    TopupMethod? method,
    String? amount,
    String? account,
    String? holder,
    Failure? Function()? failure,
  }) {
    return WithdrawState(
      status: status ?? this.status,
      balancePiastres: balancePiastres,
      minPiastres: minPiastres,
      method: method ?? this.method,
      amount: amount ?? this.amount,
      account: account ?? this.account,
      holder: holder ?? this.holder,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    balancePiastres,
    minPiastres,
    method,
    amount,
    account,
    holder,
    failure,
  ];
}
