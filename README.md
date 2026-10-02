# Salahly (صلحلي)

Flutter app (Android and iOS), Arabic and RTL, backed by Supabase.

## Run

```sh
flutter pub get
flutter gen-l10n
flutter run --flavor dev --dart-define-from-file=env/dev.json
```

Copy `env/dev.example.json` to `env/dev.json` and fill in the Supabase URL
and publishable key. Android flavors: `dev`, `staging`, `prod`.

## Checks

```sh
dart format .
flutter analyze
flutter test
```

## Backend (Supabase)

Schema, policies and RPCs live in `supabase/migrations`; pgTAP tests in
`supabase/tests/database`. With Docker running:

```sh
export SUPABASE_AUTH_SMS_TWILIO_AUTH_TOKEN=unused-locally
supabase start            # full local stack, test OTP 123456 for +15555550100..03
supabase test db          # pgTAP
supabase db lint
```

Rules the schema follows:

- Row level security on every table. Clients only `select` their own rows;
  every write goes through a `security definer` RPC with `search_path = ''`
  that validates its input.
- Internal tables and helpers live in the `private` schema, which the API
  roles cannot reach.
- Money is stored in piastres (`bigint`).
- Uploaded photos are re-encoded on the device to drop EXIF/GPS, and can
  only be written to the uploader's own folder.
- Never push `supabase/config.toml` auth settings (test OTPs) to a hosted
  project.

## Structure (clean architecture)

```
lib/
  main.dart
  salahly_app.dart
  app_dependencies.dart  builds the repositories and services once
  core/            shared code: config, error (Failure, Result), router,
                   theme, widgets, storage, location, media, text helpers
  features/<name>/
    data/          datasources, models, repositories
    domain/        entities, repositories, usecases
    presentation/  cubit, pages, widgets
  l10n/            app_ar.arb
```

- State: one Cubit per screen or flow (`flutter_bloc`), states are
  immutable `Equatable` classes.
- Dependencies: `RepositoryProvider`/`BlocProvider`, no service locator.
- Errors: repositories return `Result<T>` (`Ok`/`Err` with a `Failure`) and
  never throw to the UI.
- Use cases exist only where they orchestrate several repository calls
  (for example `SubmitTechnicianOnboarding`); otherwise a Cubit calls the
  repository directly.
- Tests mirror `lib/` under `test/`.
