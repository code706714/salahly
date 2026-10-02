/// Compile-time configuration passed with `--dart-define-from-file`.
class Env {
  const Env._({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
  });

  factory Env.fromDefines() {
    const url = String.fromEnvironment('SUPABASE_URL');
    const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
    if (url.isEmpty || key.isEmpty) {
      throw StateError(
        'Missing SUPABASE_URL or SUPABASE_PUBLISHABLE_KEY. Run with '
        '--dart-define-from-file=env/<flavor>.json',
      );
    }
    return const Env._(supabaseUrl: url, supabasePublishableKey: key);
  }

  final String supabaseUrl;
  final String supabasePublishableKey;
}
