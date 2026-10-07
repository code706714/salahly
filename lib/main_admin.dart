import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:salahly/core/config/env.dart';
import 'package:salahly/features/admin/admin_app.dart';
import 'package:salahly/features/admin/admin_dependencies.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The team's web console. Build it with
/// `flutter build web --target lib/main_admin.dart
/// --dart-define-from-file=env/dev.json`.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The console shows Western digits (0-9) everywhere, dates included.
  DateFormat.useNativeDigitsByDefaultFor('ar', false);

  final env = Env.fromDefines();
  // The session lives in the browser's own storage, which is what the
  // Supabase client uses on the web by default.
  await Supabase.initialize(
    url: env.supabaseUrl,
    publishableKey: env.supabasePublishableKey,
  );

  runApp(
    AdminApp(dependencies: AdminDependencies.live(Supabase.instance.client)),
  );
}
