part of 'customer_form_cubit.dart';

enum CustomerFormStatus {
  /// Reading the customer being edited, or waiting on the contact picker.
  loading,
  editing,
  saving,
  deleting,

  /// Done: the page closes with [CustomerFormState.saved].
  saved,

  /// The customer was deleted; the page goes back to the customers tab.
  deleted,

  /// Nothing to show: the contact picker was dismissed, or the customer
  /// to edit is gone. The page closes with nothing.
  cancelled,
}

final class CustomerFormState extends Equatable {
  const CustomerFormState({
    required this.isEditing,
    this.status = CustomerFormStatus.loading,
    this.name = '',
    this.phoneText = '',
    this.areaId,
    this.address = '',
    this.notes = '',
    this.source = CustomerSource.manual,
    this.showErrors = false,
    this.duplicate,
    this.failure,
    this.saved,
  });

  /// Editing an existing customer rather than adding one.
  final bool isEditing;
  final CustomerFormStatus status;
  final String name;

  /// As typed; optional.
  final String phoneText;
  final String? areaId;
  final String address;
  final String notes;
  final CustomerSource source;

  /// Whether to point out what is missing, after a save was tried.
  final bool showErrors;

  /// The customer who already has the number typed.
  final Customer? duplicate;

  /// Why the last save or delete failed.
  final Failure? failure;

  /// The customer to close the page with.
  final Customer? saved;

  bool get isBusy =>
      status == CustomerFormStatus.saving ||
      status == CustomerFormStatus.deleting;

  bool get isNameValid => isValidName(name);

  PhoneNumber? get phone => PhoneNumber.tryParse(phoneText);

  /// Empty, or an Egyptian mobile number.
  bool get isPhoneValid => digitsOnly(phoneText).isEmpty || phone != null;

  /// What to save, tidied the way the server stores it.
  CustomerDraft get draft => CustomerDraft(
    name: normalizeName(name),
    phone: phone,
    areaId: areaId,
    address: normalizeText(address),
    notes: normalizeText(notes),
    source: source,
  );

  CustomerFormState copyWith({
    CustomerFormStatus? status,
    String? name,
    String? phoneText,
    String? Function()? areaId,
    String? address,
    String? notes,
    CustomerSource? source,
    bool? showErrors,
    Customer? Function()? duplicate,
    Failure? Function()? failure,
    Customer? saved,
  }) {
    return CustomerFormState(
      isEditing: isEditing,
      status: status ?? this.status,
      name: name ?? this.name,
      phoneText: phoneText ?? this.phoneText,
      areaId: areaId == null ? this.areaId : areaId(),
      address: address ?? this.address,
      notes: notes ?? this.notes,
      source: source ?? this.source,
      showErrors: showErrors ?? this.showErrors,
      duplicate: duplicate == null ? this.duplicate : duplicate(),
      failure: failure == null ? this.failure : failure(),
      saved: saved ?? this.saved,
    );
  }

  @override
  List<Object?> get props => [
    isEditing,
    status,
    name,
    phoneText,
    areaId,
    address,
    notes,
    source,
    showErrors,
    duplicate,
    failure,
    saved,
  ];
}
