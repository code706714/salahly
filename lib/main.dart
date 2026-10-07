import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salahly/app_dependencies.dart';
import 'package:salahly/core/config/env.dart';
import 'package:salahly/core/storage/fresh_install.dart';
import 'package:salahly/core/storage/secure_session_storage.dart';
import 'package:salahly/features/notifications/data/services/firebase_push_transport.dart';
import 'package:salahly/salahly_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The app shows Western digits (0-9) everywhere, dates included.
  DateFormat.useNativeDigitsByDefaultFor('ar', false);

  final env = Env.fromDefines();
  const storage = FlutterSecureStorage();
  await clearSecureStorageAfterReinstall(storage);
  await Supabase.initialize(
    url: env.supabaseUrl,
    publishableKey: env.supabasePublishableKey,
    authOptions: const FlutterAuthClientOptions(
      localStorage: SecureSessionStorage(storage),
    ),
  );

  // Push works only in a build with Firebase's configuration; without it
  // this is a transport that does nothing.
  final pushTransport = await createPushTransport();

  final supportDirectory = await getApplicationSupportDirectory();
  final cacheDirectory = await getTemporaryDirectory();

  runApp(
    SalahlyApp(
      dependencies: AppDependencies.live(
        client: Supabase.instance.client,
        storage: storage,
        supportDirectory: supportDirectory,
        cacheDirectory: cacheDirectory,
        pushTransport: pushTransport,
      ),
    ),
  );
}
