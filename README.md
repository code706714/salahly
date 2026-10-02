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

## Structure (clean architecture)

```
lib/
  main.dart
  salahly_app.dart
  core/            shared config, router and theme (errors, network and
                   utils are added here when needed)
  features/<name>/
    data/          datasources, models, repositories
    domain/        entities, repositories, usecases
    presentation/  cubit, pages, widgets
  l10n/            app_ar.arb
```
