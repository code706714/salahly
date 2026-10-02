# صلحلي (Salahly)

Arabic, offline-first app that connects Egyptian customers with technicians,
and gives technicians their jobs, quotes, invoices and payments in one place.

| Path | What |
| --- | --- |
| `apps/mobile` | The Flutter app for technicians and customers |
| `packages/ui` | Design system: colors, spacing, radii, theme, font |
| `docs/adr` | Architecture decisions |

## Run

```sh
flutter pub get
cp apps/mobile/env/dev.example.json apps/mobile/env/dev.json   # fill in values
cd apps/mobile
flutter run --flavor dev --dart-define-from-file=env/dev.json
```

Flutter version is pinned in `.fvmrc`.
