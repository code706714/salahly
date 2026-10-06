import 'package:equatable/equatable.dart';
import 'package:salahly/features/marketplace/domain/entities/request_issue.dart';
import 'package:salahly/features/marketplace/domain/entities/review.dart';

/// What a consumer sees of a technician next to an offer.
final class TechnicianCard extends Equatable {
  const TechnicianCard({
    required this.id,
    required this.name,
    required this.avatarPath,
    required this.yearsExperience,
    required this.verified,
    required this.reviewCount,
    required this.jobsDone,
    this.shopName,
    this.rating,
  });

  final String id;
  final String name;
  final String? shopName;

  /// Path in the public avatars bucket.
  final String avatarPath;
  final int yearsExperience;

  /// Their ID card was checked.
  final bool verified;

  /// Average stars, one decimal, or null before the first review.
  final double? rating;
  final int reviewCount;

  /// Platform jobs they finished.
  final int jobsDone;

  @override
  List<Object?> get props => [
    id,
    name,
    shopName,
    avatarPath,
    yearsExperience,
    verified,
    rating,
    reviewCount,
    jobsDone,
  ];
}

/// A technician's page: their card plus where they work, their prices and
/// what customers said.
final class TechnicianPublicProfile extends Equatable {
  const TechnicianPublicProfile({
    required this.card,
    required this.areaIds,
    required this.services,
    required this.reviews,
    this.onTimePercent,
  });

  final TechnicianCard card;

  /// How often they started within 30 minutes of the time they offered,
  /// once they have three platform jobs started.
  final int? onTimePercent;
  final List<String> areaIds;
  final List<ServicePrice> services;

  /// Newest first, at most 30.
  final List<PublicReview> reviews;

  @override
  List<Object?> get props => [card, onTimePercent, areaIds, services, reviews];
}

/// "كشف وتنظيف · من 350 ج.م".
final class ServicePrice extends Equatable {
  const ServicePrice({
    required this.serviceId,
    required this.startingPricePiastres,
  });

  final String serviceId;
  final int startingPricePiastres;

  @override
  List<Object?> get props => [serviceId, startingPricePiastres];
}

/// A review as anyone reading a technician's page sees it.
final class PublicReview extends Equatable {
  const PublicReview({
    required this.author,
    required this.stars,
    required this.issue,
    required this.createdAt,
    this.comment,
    this.tags = const {},
  });

  /// First name and initial: "دعاء م.".
  final String author;
  final int stars;
  final String? comment;
  final Set<ReviewTag> tags;

  /// What the job was about.
  final RequestIssue issue;
  final DateTime createdAt;

  @override
  List<Object?> get props => [author, stars, comment, tags, issue, createdAt];
}
