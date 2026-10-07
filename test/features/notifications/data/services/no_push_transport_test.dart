import 'package:flutter_test/flutter_test.dart';
import 'package:salahly/features/notifications/data/services/no_push_transport.dart';
import 'package:salahly/features/notifications/domain/entities/push_notice.dart';

void main() {
  test('a build without Firebase receives and registers nothing', () async {
    const transport = NoPushTransport();

    expect(transport.isAvailable, isFalse);
    expect(await transport.permission(), PushPermission.denied);
    expect(await transport.requestPermission(), PushPermission.denied);
    expect(await transport.token(), isNull);
    expect(await transport.initialOpened(), isNull);
    await transport.deleteToken();
    expect(await transport.tokenRefreshes.isEmpty, isTrue);
    expect(await transport.foreground.isEmpty, isTrue);
    expect(await transport.opened.isEmpty, isTrue);
  });
}
