import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:salahly/core/contacts/contact_picker.dart';
import 'package:salahly/core/error/failure.dart';
import 'package:salahly/core/error/result.dart';
import 'package:salahly/core/phone/phone_number.dart';
import 'package:salahly/core/text/digits.dart';
import 'package:salahly/core/text/normalize.dart';
import 'package:salahly/core/text/person_name.dart';
import 'package:salahly/features/customers/domain/entities/customer.dart';
import 'package:salahly/features/customers/domain/repositories/customers_repository.dart';

part 'customer_form_state.dart';

/// Adds a customer, from scratch or from a contact, or edits or deletes
/// one.
class CustomerFormCubit extends Cubit<CustomerFormState> {
  CustomerFormCubit({
    required this._customers,
    required this._contacts,
    this._customerId,
    this._fromContacts = false,
  }) : super(CustomerFormState(isEditing: _customerId != null));

  final CustomersRepository _customers;
  final ContactPicker _contacts;
  final String? _customerId;
  final bool _fromContacts;

  /// Fills the form with the customer being edited or the contact picked.
  Future<void> load() async {
    try {
      final id = _customerId;
      if (id != null) {
        await _loadCustomer(id);
      } else if (_fromContacts) {
        await _pickContact();
      } else {
        emit(state.copyWith(status: CustomerFormStatus.editing));
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(status: CustomerFormStatus.cancelled));
      }
    }
  }

  Future<void> _loadCustomer(String id) async {
    final customer = (await _customers.watchCustomer(id).first)?.customer;
    if (isClosed) return;
    if (customer == null) {
      emit(state.copyWith(status: CustomerFormStatus.cancelled));
      return;
    }
    emit(
      state.copyWith(
        status: CustomerFormStatus.editing,
        name: customer.name,
        phoneText: _phoneText(customer.phone),
        areaId: () => customer.areaId,
        address: customer.address ?? '',
        notes: customer.notes ?? '',
        source: customer.source,
      ),
    );
  }

  /// A contact already a customer is that customer; nothing to fill.
  Future<void> _pickContact() async {
    final contact = await _contacts.pickPhoneNumber();
    if (isClosed) return;
    if (contact == null) {
      emit(state.copyWith(status: CustomerFormStatus.cancelled));
      return;
    }
    final phone = PhoneNumber.tryParse(contact.phone);
    final existing = phone == null ? null : await _customers.findByPhone(phone);
    if (isClosed) return;
    if (existing != null) {
      emit(state.copyWith(status: CustomerFormStatus.saved, saved: existing));
      return;
    }
    final name = normalizeName(contact.name);
    emit(
      state.copyWith(
        status: CustomerFormStatus.editing,
        name: name.length > maxNameLength
            ? name.substring(0, maxNameLength)
            : name,
        phoneText: phone == null
            ? digitsOnly(contact.phone)
            : _phoneText(phone),
        source: CustomerSource.contacts,
      ),
    );
  }

  /// The way Egyptians write it, digits only: 01228703314.
  static String _phoneText(PhoneNumber? phone) =>
      phone == null ? '' : '0${phone.nationalNumber}';

  void nameChanged(String name) => emit(state.copyWith(name: name));

  void phoneChanged(String phoneText) =>
      emit(state.copyWith(phoneText: phoneText, duplicate: () => null));

  void areaChanged(String? areaId) =>
      emit(state.copyWith(areaId: () => areaId));

  void addressChanged(String address) => emit(state.copyWith(address: address));

  void notesChanged(String notes) => emit(state.copyWith(notes: notes));

  /// Saves the customer, unless the form is incomplete or their number
  /// belongs to another customer already.
  Future<void> save() async {
    if (state.status != CustomerFormStatus.editing) return;
    if (!state.isNameValid || !state.isPhoneValid) {
      emit(state.copyWith(showErrors: true, failure: () => null));
      return;
    }
    emit(
      state.copyWith(
        status: CustomerFormStatus.saving,
        failure: () => null,
        duplicate: () => null,
      ),
    );
    Result<Customer> result;
    try {
      final phone = state.phone;
      final existing = phone == null
          ? null
          : await _customers.findByPhone(phone);
      if (existing != null && existing.id != _customerId) {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: CustomerFormStatus.editing,
              duplicate: () => existing,
            ),
          );
        }
        return;
      }
      final id = _customerId;
      result = id == null
          ? await _customers.addCustomer(state.draft)
          : await _update(id);
    } on Object catch (error) {
      result = Err(UnexpectedFailure(error));
    }
    if (isClosed) return;
    emit(switch (result) {
      Ok(value: final customer) => state.copyWith(
        status: CustomerFormStatus.saved,
        saved: customer,
      ),
      Err(:final failure) => state.copyWith(
        status: CustomerFormStatus.editing,
        failure: () => failure,
      ),
    });
  }

  /// Saves the changes and returns the customer as stored.
  Future<Result<Customer>> _update(String id) async {
    final result = await _customers.updateCustomer(id, state.draft);
    if (result case Err(:final failure)) return Err(failure);
    final record = await _customers.watchCustomer(id).first;
    return record == null
        ? const Err(UnexpectedFailure())
        : Ok(record.customer);
  }

  /// Deletes the customer being edited, with their units and jobs.
  Future<void> delete() async {
    final id = _customerId;
    if (id == null || state.status != CustomerFormStatus.editing) return;
    emit(
      state.copyWith(status: CustomerFormStatus.deleting, failure: () => null),
    );
    final result = await _customers.deleteCustomer(id);
    if (isClosed) return;
    emit(switch (result) {
      Ok() => state.copyWith(status: CustomerFormStatus.deleted),
      Err(:final failure) => state.copyWith(
        status: CustomerFormStatus.editing,
        failure: () => failure,
      ),
    });
  }
}
