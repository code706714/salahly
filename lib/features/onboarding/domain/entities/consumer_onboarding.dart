import 'package:equatable/equatable.dart';
import 'package:salahly/features/account/domain/entities/honorific.dart';

final class ConsumerOnboarding extends Equatable {
  const ConsumerOnboarding({
    required this.fullName,
    required this.honorific,
    required this.areaId,
  });

  final String fullName;
  final Honorific honorific;
  final String areaId;

  @override
  List<Object?> get props => [fullName, honorific, areaId];
}
