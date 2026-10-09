part of 'consumer_onboarding_cubit.dart';

final class ConsumerOnboardingState extends Equatable {
  const ConsumerOnboardingState({
    this.loadStatus = LoadStatus.loading,
    this.areas = const [],
    this.freeRequests = 0,
    this.fullName = '',
    this.honorific,
    this.area,
    this.areaSource = AreaSource.manual,
    this.isLocating = false,
    this.locationFailure,
    this.showErrors = false,
    this.isSubmitting = false,
    this.isDone = false,
    this.failure,
  });

  final LoadStatus loadStatus;
  final List<ServiceArea> areas;
  final int freeRequests;
  final String fullName;
  final Honorific? honorific;
  final ServiceArea? area;
  final AreaSource areaSource;
  final bool isLocating;
  final Failure? locationFailure;

  /// The user tried to continue, so missing fields are flagged.
  final bool showErrors;
  final bool isSubmitting;
  final bool isDone;

  /// Why loading or submitting failed.
  final Failure? failure;

  bool get isNameValid => isValidName(fullName);

  bool get isComplete => isNameValid && honorific != null && area != null;

  ConsumerOnboardingState copyWith({
    LoadStatus? loadStatus,
    List<ServiceArea>? areas,
    int? freeRequests,
    String? fullName,
    Honorific? honorific,
    ServiceArea? area,
    AreaSource? areaSource,
    bool? isLocating,
    Failure? Function()? locationFailure,
    bool? showErrors,
    bool? isSubmitting,
    bool? isDone,
    Failure? Function()? failure,
  }) {
    return ConsumerOnboardingState(
      loadStatus: loadStatus ?? this.loadStatus,
      areas: areas ?? this.areas,
      freeRequests: freeRequests ?? this.freeRequests,
      fullName: fullName ?? this.fullName,
      honorific: honorific ?? this.honorific,
      area: area ?? this.area,
      areaSource: areaSource ?? this.areaSource,
      isLocating: isLocating ?? this.isLocating,
      locationFailure: locationFailure != null
          ? locationFailure()
          : this.locationFailure,
      showErrors: showErrors ?? this.showErrors,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isDone: isDone ?? this.isDone,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    loadStatus,
    areas,
    freeRequests,
    fullName,
    honorific,
    area,
    areaSource,
    isLocating,
    locationFailure,
    showErrors,
    isSubmitting,
    isDone,
    failure,
  ];
}
