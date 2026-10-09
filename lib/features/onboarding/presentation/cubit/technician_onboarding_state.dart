part of 'technician_onboarding_cubit.dart';

enum TechnicianStep { profile, services, location, documents, done }

enum DocumentSlot { idFront, idBack, selfieWithId }

final class TechnicianOnboardingState extends Equatable {
  const TechnicianOnboardingState({
    this.loadStatus = LoadStatus.loading,
    this.categories = const [],
    this.areas = const [],
    this.freeJobs = 0,
    this.step = TechnicianStep.profile,
    this.avatarPath,
    this.fullName = '',
    this.shopName = '',
    this.yearsText = '',
    this.selectedServiceIds = const {},
    this.priceTexts = const {},
    this.baseArea,
    this.baseLocation,
    this.baseSource = AreaSource.manual,
    this.isLocating = false,
    this.locationFailure,
    this.radiusKm = 10,
    this.areaIds = const {},
    this.workDays = defaultWorkDays,
    this.documents = const {},
    this.showErrors = false,
    this.isSubmitting = false,
    this.failure,
  });

  static const radiusOptions = [5, 10, 15];

  /// Saturday to Thursday, as ISO weekdays.
  static const defaultWorkDays = {6, 7, 1, 2, 3, 4};

  final LoadStatus loadStatus;
  final List<ServiceCategory> categories;
  final List<ServiceArea> areas;
  final int freeJobs;
  final TechnicianStep step;

  final String? avatarPath;
  final String fullName;
  final String shopName;
  final String yearsText;

  final Set<String> selectedServiceIds;

  /// Starting price per service in whole pounds, as typed.
  final Map<String, String> priceTexts;

  final ServiceArea? baseArea;
  final GeoPoint? baseLocation;
  final AreaSource baseSource;
  final bool isLocating;
  final Failure? locationFailure;
  final int radiusKm;
  final Set<String> areaIds;

  /// ISO weekdays: 1 = Monday ... 6 = Saturday, 7 = Sunday.
  final Set<int> workDays;

  /// Local paths of the ID photos taken so far.
  final Map<DocumentSlot, String> documents;

  /// The user tried to leave the current step with something missing.
  final bool showErrors;
  final bool isSubmitting;

  /// Why loading or submitting failed.
  final Failure? failure;

  bool get isNameValid => isValidName(fullName);

  bool get isShopNameValid =>
      normalizeName(shopName).isEmpty || isValidName(shopName);

  int? get yearsExperience {
    final years = parseWholeNumber(yearsText);
    return years != null && years <= 60 ? years : null;
  }

  bool get isProfileValid =>
      avatarPath != null &&
      isNameValid &&
      isShopNameValid &&
      yearsExperience != null;

  /// The typed price of [serviceId] in piastres, if it's a valid amount.
  int? pricePiastres(String serviceId) =>
      parseStartingPrice(priceTexts[serviceId] ?? '');

  bool get isServicesValid =>
      selectedServiceIds.isNotEmpty &&
      selectedServiceIds.every((id) => pricePiastres(id) != null);

  bool get isLocationValid =>
      baseArea != null && areaIds.isNotEmpty && workDays.isNotEmpty;

  bool get isDocumentsValid => documents.length == DocumentSlot.values.length;

  bool get isCurrentStepValid => switch (step) {
    TechnicianStep.profile => isProfileValid,
    TechnicianStep.services => isServicesValid,
    TechnicianStep.location => isLocationValid,
    TechnicianStep.documents => isDocumentsValid,
    TechnicianStep.done => true,
  };

  /// The areas to offer as chips: the closest ones plus any already chosen.
  List<ServiceArea> get suggestedAreas {
    final base = baseLocation;
    final ordered = base == null ? areas : areasByDistance(areas, base);
    final nearby = ordered.take(6).toSet();
    return [
      ...nearby,
      ...areas.where(
        (area) => areaIds.contains(area.id) && !nearby.contains(area),
      ),
    ];
  }

  TechnicianOnboardingState copyWith({
    LoadStatus? loadStatus,
    List<ServiceCategory>? categories,
    List<ServiceArea>? areas,
    int? freeJobs,
    TechnicianStep? step,
    String? avatarPath,
    String? fullName,
    String? shopName,
    String? yearsText,
    Set<String>? selectedServiceIds,
    Map<String, String>? priceTexts,
    ServiceArea? baseArea,
    GeoPoint? baseLocation,
    AreaSource? baseSource,
    bool? isLocating,
    Failure? Function()? locationFailure,
    int? radiusKm,
    Set<String>? areaIds,
    Set<int>? workDays,
    Map<DocumentSlot, String>? documents,
    bool? showErrors,
    bool? isSubmitting,
    Failure? Function()? failure,
  }) {
    return TechnicianOnboardingState(
      loadStatus: loadStatus ?? this.loadStatus,
      categories: categories ?? this.categories,
      areas: areas ?? this.areas,
      freeJobs: freeJobs ?? this.freeJobs,
      step: step ?? this.step,
      avatarPath: avatarPath ?? this.avatarPath,
      fullName: fullName ?? this.fullName,
      shopName: shopName ?? this.shopName,
      yearsText: yearsText ?? this.yearsText,
      selectedServiceIds: selectedServiceIds ?? this.selectedServiceIds,
      priceTexts: priceTexts ?? this.priceTexts,
      baseArea: baseArea ?? this.baseArea,
      baseLocation: baseLocation ?? this.baseLocation,
      baseSource: baseSource ?? this.baseSource,
      isLocating: isLocating ?? this.isLocating,
      locationFailure: locationFailure != null
          ? locationFailure()
          : this.locationFailure,
      radiusKm: radiusKm ?? this.radiusKm,
      areaIds: areaIds ?? this.areaIds,
      workDays: workDays ?? this.workDays,
      documents: documents ?? this.documents,
      showErrors: showErrors ?? this.showErrors,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    loadStatus,
    categories,
    areas,
    freeJobs,
    step,
    avatarPath,
    fullName,
    shopName,
    yearsText,
    selectedServiceIds,
    priceTexts,
    baseArea,
    baseLocation,
    baseSource,
    isLocating,
    locationFailure,
    radiusKm,
    areaIds,
    workDays,
    documents,
    showErrors,
    isSubmitting,
    failure,
  ];
}
