# Release checklist (ship / no-ship)

Gate from the security-and-testing skill, Part C. A build ships only if every row is done. **Done** = true at this commit. **Blocked on amr** = needs his accounts or devices; steps below.

| # | Gate | State | Evidence or next step |
|---|---|---|---|
| 1 | CI green on the release commit (format, analyze, unit, widget, golden, pgTAP) | Done locally | `flutter analyze`, `dart format`, `flutter test`, pgTAP files 00-65 pass. Re-check the CI run on the tag. Integration tests do not exist yet; the `purge-storage` Deno tests exist (`deno test supabase/functions/purge-storage`) but CI does not run them yet, so run them by hand. |
| 2 | RLS on every table, matrix tests pass | Done | `00_security_baseline` plus 10-65. Test 5 (`plpgsql_` functions) and 6 fail only on the local stack, not on hosted. |
| 3 | No secrets in repo or AAB | Partly | gitleaks runs in CI; `env/*.json` is ignored; keystore is read from env. Blocked on amr: after the first build run `unzip -p app.aab | strings` for `service_role` and `BEGIN PRIVATE KEY`. |
| 4 | E2E on 2 low-end devices (Android 8-10, 2-3 GB) | Blocked on amr | No Patrol suite yet; do the manual script on two real devices or Firebase Test Lab. |
| 5 | Manual QA by someone other than the author | Blocked on amr | Both roles: sign-up, request, offer, pick, job, review, top-up, notifications, delete account. |
| 6 | Closed testing at least 14 days with 12 testers (new personal account) | Blocked on amr | Play Console steps below. Crash-free at least 99.5%, no open P0/P1. |
| 7 | Migrations backward compatible, backup, rollback written | Partly | Migrations are additive, except M5, which relaxes some NOT NULLs and replaces two foreign keys (`credit_topups.user_id`, `credit_ledger.user_id`); that is backward compatible with the old client. Before pushing: take a backup (below). Rollback: the previous app keeps working because no column or table was dropped or renamed. |
| 8 | Privacy policy, Data safety, permissions, deletion match the build | Done in repo | `assets/legal/*`, `docs/release/data-safety.md`, `docs/legal/delete-account.md`. Blocked on amr: publish the web page and enter its URL in Play. Confirm the support email in that page (placeholder `support@salahly.app`). |
| 9 | Crash reporting with symbols, alerts, on-call named | Blocked on amr | No Sentry/Crashlytics in the app. The release workflow uploads Dart symbols as an artifact; choose a tool and name the person for the first 72 hours. |
| 10 | Staged rollout 10% > 50% > 100%, halt criteria | Blocked on amr | Set in Play Console; halt if crash-free below 99.5%, error spike or 1-star spike. |

Verdict today: **no-ship** until rows 3 (AAB spot check), 4, 5, 6, 9, 10 are done.

## Decisions for amr
- Deleting a consumer removes their reviews and complaints, and deleting a technician removes his finished requests from consumers' history. Anonymizing them instead is an option.

## Keystore (once, on amr's machine)
```
keytool -genkeypair -v -keystore salahly-upload.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
base64 -w0 salahly-upload.jks   # paste into the GitHub secret
```
Keep the .jks and passwords in a password manager, never in the repo. Use Play App Signing: this is only the upload key, so a lost key can be reset by Play support.

GitHub: Settings > Environments > `production`, add required reviewers, then add secrets `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY` (hosted project's URL and publishable key, never the secret key). Run Actions > Release, or push a `vX.Y.Z` tag. Bump `version:` in pubspec.yaml first (build number must rise on every upload). Local signed build: export `ANDROID_KEYSTORE_PATH`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, then `flutter build appbundle --release --flavor prod --obfuscate --split-debug-info=build/symbols --dart-define-from-file=env/prod.json`. This session had no Android SDK, so the release build is verified only by the workflow's first run.

## Play Console
1. Create a developer account (personal or organization; a new personal account needs the 14-day, 12-tester closed test).
2. Create app: Arabic, free, app name from `store-listing-ar.md`. Package `com.salahly.app`.
3. App content: privacy policy URL, Data safety (`data-safety.md`), data deletion URL, content rating, target audience 18+, ads: none.
4. Main store listing from `store-listing-ar.md` with screenshots and 1024x500 graphic.
5. Closed testing: upload the AAB, add 12+ testers by Google group, run 14 days.
6. Production: staged rollout 10%, then 50%, then 100%.

## Twilio (sign-in codes)
1. Create a Verify service with the WhatsApp channel enabled (SMS as fallback); note the Service SID, Account SID and Auth Token.
2. Verify > Settings: code length 6, expiry 10 minutes or less.
3. Messaging > Settings > Geo permissions: allow Egypt only.
4. Enable Fraud Guard (SMS pumping protection); set a daily spend alert and a hard usage cap.
5. WhatsApp sender needs Meta business verification and an approved template; until then expect SMS only.
6. In Supabase, Auth > Providers > Phone: Twilio Verify, paste the three values. Rate limits: Auth > Rate Limits, keep SMS per hour low (for example 5 per number) and the 60 s resend gap.

## Supabase hosted project
1. Create the project in the region nearest Egypt (eu-central or similar); enable PITR or take a manual backup before each push.
2. `supabase link`, then `supabase db push`. Do not push `config.toml` auth settings: the local test OTP numbers and placeholder Twilio values must never reach hosted. Set Auth by hand as in Twilio step 6; turn off sign-ups by email.
3. Extensions: `pg_cron` and `pg_net` enabled (Database > Extensions) before the migrations run.
4. Purge of deleted accounts' files (account deletion queues them; without this step files stay):
   - `supabase functions deploy purge-storage --no-verify-jwt`
   - `supabase secrets set PURGE_STORAGE_SECRET=<random value, at least 32 characters>`
   - SQL editor: `select vault.create_secret('https://<ref>.supabase.co/functions/v1/purge-storage', 'purge_storage_url');` and `select vault.create_secret('<same random value>', 'purge_storage_secret');`
   - Check: delete a test account, then within 15 minutes `select count(*) from private.storage_purge` returns 0 and the bucket files are gone. Also wire an alert on `select private.purge_backlog()` (age of the oldest file still waiting; alert above 1 hour) and add the secret `free_credit_pepper` (`select vault.create_secret('<long random value>', 'free_credit_pepper');`) before launch. Keep it forever: losing it re-opens the free uses for deleted accounts.
5. Seed what the app needs on hosted: payment accounts (Vodafone Cash / InstaPay numbers), credit packs, app_settings free-use counts, and at least one staff account allowed to approve technicians and top-ups.
6. Check the Security Advisor shows no table without RLS, and add a billing alert.

## Firebase (push, later)
1. Create a Firebase project and add the Android app `com.salahly.app` (and `.dev`/`.staging` if wanted); download `google-services.json` (not committed).
2. Cloud Messaging: enable, create a service account for server sends.
3. Each notification is already a row in `public.notifications`; push is a database webhook or Edge Function that reads new rows and sends FCM. Add a `device_tokens` table with RLS when building it.
4. Then update `data-safety.md` and the privacy policy (device token) and re-submit the form.
