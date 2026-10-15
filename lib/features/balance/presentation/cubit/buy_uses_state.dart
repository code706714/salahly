part of 'buy_uses_cubit.dart';

enum BuyUsesStatus { loading, failed, editing, starting, paying }

final class BuyUsesState extends Equatable {
  const BuyUsesState({
    this.status = BuyUsesStatus.loading,
    this.packs = const [],
    this.packId,
    this.checkout,
    this.failure,
  });

  final BuyUsesStatus status;
  final List<CreditPack> packs;
  final String? packId;

  /// The payment page to pay on, while [status] is `paying`.
  final PaymentCheckout? checkout;

  /// Why loading or the last start failed.
  final Failure? failure;

  CreditPack? get pack => packs.where((pack) => pack.id == packId).firstOrNull;

  /// What one use costs alone: the pack of a single use, if one is on
  /// sale. Bigger packs show what they save against it.
  int? get singlePricePiastres =>
      packs.where((pack) => pack.uses == 1).firstOrNull?.pricePiastres;

  bool get canPay => status == BuyUsesStatus.editing && pack != null;

  BuyUsesState copyWith({
    BuyUsesStatus? status,
    List<CreditPack>? packs,
    String? packId,
    PaymentCheckout? Function()? checkout,
    Failure? Function()? failure,
  }) {
    return BuyUsesState(
      status: status ?? this.status,
      packs: packs ?? this.packs,
      packId: packId ?? this.packId,
      checkout: checkout != null ? checkout() : this.checkout,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [status, packs, packId, checkout, failure];
}
