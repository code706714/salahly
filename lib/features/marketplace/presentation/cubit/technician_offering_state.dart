part of 'technician_offering_cubit.dart';

enum OfferingStatus { loading, failed, editing, saving, saved }

final class TechnicianOfferingState extends Equatable {
  const TechnicianOfferingState({
    this.status = OfferingStatus.loading,
    this.categories = const [],
    this.selectedServiceIds = const {},
    this.priceTexts = const {},
    this.areaIds = const {},
    this.workDays = const {},
    this.radiusKm = 10,
    this.showsErrors = false,
    this.handedOver,
    this.failure,
  });

  /// The service radii a technician can pick, in km.
  static const radiusOptions = [5, 10, 15];

  final OfferingStatus status;

  /// The catalog, to know which services can be offered.
  final List<ServiceCategory> categories;
  final Set<String> selectedServiceIds;

  /// The typed starting price of each service, in pounds.
  final Map<String, String> priceTexts;
  final Set<String> areaIds;

  /// ISO weekdays: 1 = Monday ... 7 = Sunday.
  final Set<int> workDays;
  final int radiusKm;

  /// Whether saving was tried with something missing, so the form says what.
  final bool showsErrors;

  /// Open requests the technician was handed by the last save.
  final int? handedOver;

  /// Why loading or saving failed.
  final Failure? failure;

  /// Ticked services of the open trades; anything else the server may hold
  /// (a trade closed since) is left out of what is saved.
  Set<String> get offeredServiceIds => {
    for (final category in categories)
      if (category.isActive)
        for (final service in category.services)
          if (selectedServiceIds.contains(service.id)) service.id,
  };

  int? pricePiastres(String serviceId) =>
      parseStartingPrice(priceTexts[serviceId] ?? '');

  bool get isServicesValid =>
      offeredServiceIds.isNotEmpty &&
      offeredServiceIds.every((id) => pricePiastres(id) != null);

  bool get isValid =>
      isServicesValid && areaIds.isNotEmpty && workDays.isNotEmpty;

  TechnicianOfferingState copyWith({
    OfferingStatus? status,
    List<ServiceCategory>? categories,
    Set<String>? selectedServiceIds,
    Map<String, String>? priceTexts,
    Set<String>? areaIds,
    Set<int>? workDays,
    int? radiusKm,
    bool? showsErrors,
    int? handedOver,
    Failure? Function()? failure,
  }) {
    return TechnicianOfferingState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      selectedServiceIds: selectedServiceIds ?? this.selectedServiceIds,
      priceTexts: priceTexts ?? this.priceTexts,
      areaIds: areaIds ?? this.areaIds,
      workDays: workDays ?? this.workDays,
      radiusKm: radiusKm ?? this.radiusKm,
      showsErrors: showsErrors ?? this.showsErrors,
      handedOver: handedOver ?? this.handedOver,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    status,
    categories,
    selectedServiceIds,
    priceTexts,
    areaIds,
    workDays,
    radiusKm,
    showsErrors,
    handedOver,
    failure,
  ];
}
