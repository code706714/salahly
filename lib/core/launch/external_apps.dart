import 'package:salahly/core/phone/phone_number.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Other apps the technician hands off to: the dialer, WhatsApp, maps and
/// the share sheet. Each returns false when nothing could open it.
abstract interface class ExternalApps {
  Future<bool> dial(PhoneNumber phone);

  /// Opens a WhatsApp chat with [to] (or a contact picker when null) and
  /// [text] ready to send. The technician still taps send.
  Future<bool> whatsApp({required String text, PhoneNumber? to});

  Future<bool> map(String address);

  Future<bool> shareFile(String path, {required String name});
}

class SystemExternalApps implements ExternalApps {
  const SystemExternalApps();

  @override
  Future<bool> dial(PhoneNumber phone) =>
      _open(Uri(scheme: 'tel', path: phone.e164));

  @override
  Future<bool> whatsApp({required String text, PhoneNumber? to}) => _open(
    Uri.https('wa.me', to == null ? '/' : '/${to.international}', {
      'text': text,
    }),
  );

  @override
  Future<bool> map(String address) => _open(
    Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    }),
  );

  @override
  Future<bool> shareFile(String path, {required String name}) async {
    final result = await SharePlus.instance.share(
      ShareParams(files: [XFile(path, name: name)]),
    );
    return result.status != ShareResultStatus.unavailable;
  }

  Future<bool> _open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on Object {
      return false;
    }
  }
}
