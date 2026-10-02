import 'package:flutter/widgets.dart';
import 'package:salahly/core/config/env.dart';
import 'package:salahly/salahly_app.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Env.fromDefines();
  await Supabase.initialize(
    url: env.supabaseUrl,
    publishableKey: env.supabasePublishableKey,
  );
  runApp(const SalahlyApp());
}
