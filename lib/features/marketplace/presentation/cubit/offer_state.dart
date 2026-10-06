part of 'offer_cubit.dart';

enum OfferLoadStatus { loading, ready, missing, failed }

/// What the technician is doing to the request right now.
enum OfferAction { send, dismiss }

final class OfferState extends Equatable {
  const OfferState({
    required this.now,
    this.status = OfferLoadStatus.loading,
    this.request,
    this.services = const [],
    this.photoUrls = const {},
    this.busy,
    this.failure,
  });

  /// When the request was last fetched, to leave out times already past.
  final DateTime now;
  final OfferLoadStatus status;

  /// The request, once fetched; kept while a refresh fails.
  final IncomingRequest? request;

  /// The technician's own services and starting prices.
  final List<ServicePrice> services;

  /// Links to the request's photos, by path.
  final Map<String, String> photoUrls;

  /// The action in progress, if any.
  final OfferAction? busy;

  /// Why the last action failed.
  final Failure? failure;

  /// Minutes between two arrival times to pick from.
  static const arrivalStep = 30;

  /// The times the technician can offer to come: every half hour of the
  /// request's window on its day, from now on.
  List<DateTime> get arrivalChoices {
    final request = this.request;
    if (request == null) return const [];
    final day = request.day;
    final window = request.window;
    return [
      for (
        var minutes = window.startHour * 60;
        minutes < window.endHour * 60;
        minutes += arrivalStep
      )
        if (DateTime(day.year, day.month, day.day, 0, minutes) case final at
            when at.isAfter(now))
          at,
    ];
  }

  OfferState copyWith({
    DateTime? now,
    OfferLoadStatus? status,
    IncomingRequest? request,
    List<ServicePrice>? services,
    Map<String, String>? photoUrls,
    OfferAction? Function()? busy,
    Failure? Function()? failure,
  }) {
    return OfferState(
      now: now ?? this.now,
      status: status ?? this.status,
      request: request ?? this.request,
      services: services ?? this.services,
      photoUrls: photoUrls ?? this.photoUrls,
      busy: busy != null ? busy() : this.busy,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    now,
    status,
    request,
    services,
    photoUrls,
    busy,
    failure,
  ];
}
