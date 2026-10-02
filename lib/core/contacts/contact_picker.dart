import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

/// A name and number the technician picked from their phone's contacts.
typedef PickedContact = ({String name, String phone});

/// Opens the phone's own contact picker for one number. The app reads only
/// the contact picked, so it needs no permission to read all contacts.
class ContactPicker {
  ContactPicker({FlutterNativeContactPicker? picker})
    : _picker = picker ?? FlutterNativeContactPicker();

  final FlutterNativeContactPicker _picker;

  /// The contact picked, or null when cancelled or unavailable.
  Future<PickedContact?> pickPhoneNumber() async {
    try {
      final contact = await _picker.selectPhoneNumber();
      final phone = contact?.selectedPhoneNumber;
      if (contact == null || phone == null) return null;
      return (name: contact.fullName ?? '', phone: phone);
    } on Object {
      return null;
    }
  }
}
