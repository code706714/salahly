import 'package:equatable/equatable.dart';

/// One line of a job's quote and invoice.
final class JobItem extends Equatable {
  const JobItem({
    required this.id,
    required this.jobId,
    required this.title,
    required this.unitPricePiastres,
    this.quantity = 1,
    this.sortOrder = 0,
  });

  static const maxTitleLength = 80;
  static const maxQuantity = 999;

  /// One million pounds.
  static const maxUnitPricePiastres = 100000000;

  final String id;
  final String jobId;
  final String title;
  final int unitPricePiastres;
  final int quantity;
  final int sortOrder;

  int get totalPiastres => unitPricePiastres * quantity;

  @override
  List<Object?> get props => [
    id,
    jobId,
    title,
    unitPricePiastres,
    quantity,
    sortOrder,
  ];
}

/// A quote line being edited. [id] is set for lines already saved.
final class JobItemDraft extends Equatable {
  const JobItemDraft({
    required this.title,
    required this.unitPricePiastres,
    this.quantity = 1,
    this.id,
  });

  final String? id;
  final String title;
  final int unitPricePiastres;
  final int quantity;

  int get totalPiastres => unitPricePiastres * quantity;

  JobItemDraft withQuantity(int quantity) => JobItemDraft(
    id: id,
    title: title,
    unitPricePiastres: unitPricePiastres,
    quantity: quantity,
  );

  @override
  List<Object?> get props => [id, title, unitPricePiastres, quantity];
}

/// A line the technician used before, offered when adding a new one.
final class ItemSuggestion extends Equatable {
  const ItemSuggestion({required this.title, required this.unitPricePiastres});

  final String title;

  /// The most recent price used for [title].
  final int unitPricePiastres;

  @override
  List<Object?> get props => [title, unitPricePiastres];
}
