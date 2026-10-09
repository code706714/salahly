import 'package:equatable/equatable.dart';

/// The money from the jobs finished in one month.
final class MonthIncome extends Equatable {
  const MonthIncome({
    required this.jobCount,
    required this.totalPiastres,
    required this.collectedPiastres,
  });

  static const empty = MonthIncome(
    jobCount: 0,
    totalPiastres: 0,
    collectedPiastres: 0,
  );

  final int jobCount;
  final int totalPiastres;
  final int collectedPiastres;

  int get outstandingPiastres => totalPiastres - collectedPiastres;

  @override
  List<Object?> get props => [jobCount, totalPiastres, collectedPiastres];
}
