import 'package:equatable/equatable.dart';

/// Uses that can be bought together for one price.
final class CreditPack extends Equatable {
  const CreditPack({
    required this.id,
    required this.uses,
    required this.pricePiastres,
  });

  final String id;
  final int uses;
  final int pricePiastres;

  /// What one use costs in this pack, rounded to the piastre.
  int get perUsePiastres => (pricePiastres / uses).round();

  /// What buying this pack saves against paying [singlePricePiastres] for
  /// each of its uses, or 0 when it saves nothing.
  int savingsAgainst(int singlePricePiastres) {
    final saved = singlePricePiastres * uses - pricePiastres;
    return saved > 0 ? saved : 0;
  }

  @override
  List<Object?> get props => [id, uses, pricePiastres];
}
