import 'package:equatable/equatable.dart';

/// A place in the consumer's address book: "البيت", "بيت ماما".
final class ConsumerAddress extends Equatable {
  const ConsumerAddress({
    required this.id,
    required this.label,
    required this.areaId,
    required this.details,
  });

  final String id;
  final String label;
  final String areaId;

  /// Street, building and floor. Only the technician the consumer picks
  /// ever sees it.
  final String details;

  @override
  List<Object?> get props => [id, label, areaId, details];
}

/// A new address, or the edited fields of an existing one.
final class ConsumerAddressDraft extends Equatable {
  const ConsumerAddressDraft({
    required this.label,
    required this.areaId,
    required this.details,
  });

  final String label;
  final String areaId;
  final String details;

  @override
  List<Object?> get props => [label, areaId, details];
}
