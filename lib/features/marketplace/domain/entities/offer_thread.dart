import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/user_role.dart';
import 'package:salahly/features/marketplace/domain/entities/service_request.dart';

/// The prices in whole pounds, in piastres, a price talk step can take: from
/// just above [above] to just below [price]. Null when no whole pound fits.
({int min, int max})? poundsBelow(int price, {int above = 0}) {
  final min = (above ~/ 100 + 1) * 100;
  final max = (price - 1) ~/ 100 * 100;
  return min <= max ? (min: min, max: max) : null;
}

/// One step of an offer's price talk.
enum OfferEventKind {
  /// The technician's first price.
  offer,

  /// The consumer asks for a lower price.
  counter,

  /// The technician lowers their price.
  revise,

  /// The technician takes the consumer's price.
  acceptCounter,

  /// The technician takes the offer back.
  withdraw,
}

/// Where an offer's price talk stands.
final class OfferState extends Equatable {
  const OfferState({
    required this.offerId,
    required this.requestId,
    required this.status,
    required this.pricePiastres,
    required this.awaiting,
    required this.countersLeft,
    required this.revisionsLeft,
    this.counterPricePiastres,
  });

  final String offerId;
  final String requestId;
  final OfferStatus status;

  /// The technician's current price.
  final int pricePiastres;

  /// The consumer's price, while the technician has yet to answer it.
  final int? counterPricePiastres;
  final OfferTurn awaiting;

  /// Prices the consumer can still ask for.
  final int countersLeft;

  /// Times the technician can still lower their price.
  final int revisionsLeft;

  @override
  List<Object?> get props => [
    offerId,
    requestId,
    status,
    pricePiastres,
    counterPricePiastres,
    awaiting,
    countersLeft,
    revisionsLeft,
  ];
}

/// A step of the price talk: a price said by [actor], or none for taking
/// the offer back.
final class OfferEvent extends Equatable {
  const OfferEvent({
    required this.kind,
    required this.actor,
    required this.createdAt,
    this.pricePiastres,
  });

  final OfferEventKind kind;
  final UserRole actor;
  final int? pricePiastres;
  final DateTime createdAt;

  @override
  List<Object?> get props => [kind, actor, pricePiastres, createdAt];
}

/// An offer's price talk, oldest step first.
final class OfferThread extends Equatable {
  const OfferThread({required this.state, required this.events});

  final OfferState state;
  final List<OfferEvent> events;

  @override
  List<Object?> get props => [state, events];
}
