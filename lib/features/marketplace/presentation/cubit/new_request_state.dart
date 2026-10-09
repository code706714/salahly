part of 'new_request_cubit.dart';

/// The form's three steps, in order.
enum NewRequestStep { problem, address, time }

enum NewRequestStatus { editing, uploading, sending, sent, failed }

final class NewRequestState extends Equatable {
  const NewRequestState({
    required this.now,
    this.step = NewRequestStep.problem,
    this.categories = const [],
    this.category,
    this.technician,
    this.technicianServiceIds = const {},
    this.issue,
    this.description = '',
    this.isListening = false,
    this.photos = const [],
    this.addresses,
    this.addressesFailed = false,
    this.addressId,
    this.day,
    this.window,
    this.showsErrors = false,
    this.status = NewRequestStatus.editing,
    this.uploaded = 0,
    this.sent,
    this.failure,
  });

  /// The server takes a time window until an hour before it ends.
  static const windowLeadTime = Duration(hours: 1);

  /// When the time choices were last checked against the clock.
  final DateTime now;
  final NewRequestStep step;

  /// The open trades, in display order; empty until the catalog arrives.
  final List<ServiceCategory> categories;

  /// The trade picked; null until the catalog arrives.
  final ServiceCategory? category;

  /// Who the request goes to first, when the consumer asks a technician.
  final TechnicianCard? technician;

  /// The services [technician] offers, to limit the trades to theirs.
  final Set<String> technicianServiceIds;
  final RequestIssue? issue;
  final String description;

  /// Whether dictation is adding to [description].
  final bool isListening;

  /// Picked photos on the phone, uploaded when the request is sent.
  final List<String> photos;

  /// The address book, oldest first; null until fetched.
  final List<ConsumerAddress>? addresses;

  /// The address book couldn't be fetched.
  final bool addressesFailed;
  final String? addressId;

  /// Local midnight of the day asked for.
  final DateTime? day;
  final RequestWindow? window;

  /// Whether moving on was tried with something missing in this step, so
  /// the form says what.
  final bool showsErrors;
  final NewRequestStatus status;

  /// Photos uploaded so far while sending.
  final int uploaded;

  /// The request as the server took it, once [status] is sent.
  final SentRequest? sent;

  /// Why sending failed, while [status] is failed.
  final Failure? failure;

  bool get isSending =>
      status == NewRequestStatus.uploading ||
      status == NewRequestStatus.sending;

  ConsumerAddress? get address =>
      addresses?.where((address) => address.id == addressId).firstOrNull;

  /// Today, tomorrow and the day after, as local midnight.
  List<DateTime> get days => [
    for (var offset = 0; offset < 3; offset++)
      DateTime(now.year, now.month, now.day + offset),
  ];

  /// Whether [window] on [day] can still be asked for.
  bool isOpen(DateTime day, RequestWindow window) =>
      !window.endOn(day).isBefore(now.add(windowLeadTime));

  /// Whether any window on [day] can still be asked for.
  bool hasOpenWindow(DateTime day) =>
      RequestWindow.choices.any((window) => isOpen(day, window));

  /// The trades to pick from: the open ones, or only those [technician]
  /// works in once known.
  List<ServiceCategory> get categoryChoices {
    final worksIn = [
      for (final category in categories)
        if (category.services.any(
          (service) => technicianServiceIds.contains(service.id),
        ))
          category,
    ];
    return technician == null || worksIn.isEmpty ? categories : worksIn;
  }

  /// The problems of the picked trade, in display order, with the words the
  /// server gives them. Problems this version doesn't know are left out.
  List<({RequestIssue issue, String name})> get issueChoices => [
    for (final choice in category?.issues ?? const <CatalogIssue>[])
      if (RequestIssue.values
              .where((issue) => toWire(issue) == choice.id)
              .firstOrNull
          case final issue?)
        (issue: issue, name: choice.name),
  ];

  bool get needsDescription => issue == RequestIssue.other;

  bool get problemDone =>
      category != null &&
      issue != null &&
      (!needsDescription || description.trim().isNotEmpty);

  bool get addressDone => address != null;

  bool get timeDone {
    final day = this.day;
    final window = this.window;
    return day != null && window != null && isOpen(day, window);
  }

  NewRequestState copyWith({
    DateTime? now,
    NewRequestStep? step,
    List<ServiceCategory>? categories,
    ServiceCategory? category,
    TechnicianCard? technician,
    Set<String>? technicianServiceIds,
    RequestIssue? Function()? issue,
    String? description,
    bool? isListening,
    List<String>? photos,
    List<ConsumerAddress>? addresses,
    bool? addressesFailed,
    String? addressId,
    DateTime? Function()? day,
    RequestWindow? Function()? window,
    bool? showsErrors,
    NewRequestStatus? status,
    int? uploaded,
    SentRequest? sent,
    Failure? Function()? failure,
  }) {
    return NewRequestState(
      now: now ?? this.now,
      step: step ?? this.step,
      categories: categories ?? this.categories,
      category: category ?? this.category,
      technician: technician ?? this.technician,
      technicianServiceIds: technicianServiceIds ?? this.technicianServiceIds,
      issue: issue != null ? issue() : this.issue,
      description: description ?? this.description,
      isListening: isListening ?? this.isListening,
      photos: photos ?? this.photos,
      addresses: addresses ?? this.addresses,
      addressesFailed: addressesFailed ?? this.addressesFailed,
      addressId: addressId ?? this.addressId,
      day: day != null ? day() : this.day,
      window: window != null ? window() : this.window,
      showsErrors: showsErrors ?? this.showsErrors,
      status: status ?? this.status,
      uploaded: uploaded ?? this.uploaded,
      sent: sent ?? this.sent,
      failure: failure != null ? failure() : this.failure,
    );
  }

  @override
  List<Object?> get props => [
    now,
    step,
    categories,
    category,
    technician,
    technicianServiceIds,
    issue,
    description,
    isListening,
    photos,
    addresses,
    addressesFailed,
    addressId,
    day,
    window,
    showsErrors,
    status,
    uploaded,
    sent,
    failure,
  ];
}
