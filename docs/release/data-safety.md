# Play Console: Data safety form

Answers match the code at this commit. If a collection or SDK changes, change this file in the same PR.

## Overview answers
- Collects or shares user data: **Yes**.
- All data encrypted in transit: **Yes** (HTTPS only, cleartext off).
- Users can request deletion: **Yes**. In the app (Account > امسح حسابي) and on the web page `docs/legal/delete-account.md`, once published. Enter that URL in "Data deletion".
- No ads, no analytics SDK, no third-party tracking, no Firebase yet.
- Sold to anyone: **No**.

## Data types

| Play category | Data | Collected | Shared | Purpose | Optional |
|---|---|---|---|---|---|
| Personal info: Name | profile name; technician shop name | Yes | With the other party of a job | App functionality, account management | No |
| Personal info: Phone number | sign-in number | Yes | With the other party once a job is agreed | Account management, app functionality | No |
| Personal info: Address | consumer's saved address details | Yes | Only with the chosen technician | App functionality | No (needed to book) |
| Location: Approximate location | area from coarse GPS; technician position rounded to about 100 m | Yes | No | App functionality | Yes (area can be picked by hand) |
| Photos and videos: Photos | avatar, ID photos, problem photos, job photos, transfer receipts | Yes | Avatar and problem photos shown to other users; ID photos and receipts staff only | App functionality, fraud prevention | Problem photos yes; ID photos required for technicians |
| Financial info: Payment info | sender account on a manual transfer, receipt photo | Yes | No | App functionality, fraud prevention | Only when topping up |
| Messages / App activity: other user-generated content | request description, reviews, complaints, technician's customer book and invoices | Yes | Reviews and request text with the other party; the book is private | App functionality | Yes |
| App info and performance | none (no crash or analytics SDK) | No | No | n/a | n/a |
| Device or other IDs | none (no advertising ID) | No | No | n/a | n/a |
| Audio | not collected: dictation uses the phone's speech recognizer and nothing is recorded or uploaded by the app | No | No | n/a | n/a |

"Shared" in the form means sent to a third party. Other users of the app and our hosting and SMS/WhatsApp providers acting for us (service providers) are not "sharing" under Play's definition, so the Shared column in the form is **No** for all rows. Say so in the policy (done).

## Security practices
- Encrypted in transit: yes.
- Deletion mechanism: yes (in app and web URL).
- Session stored in the Android Keystore through flutter_secure_storage; backups disabled (`allowBackup=false`, data extraction rules exclude everything).

## Permissions declared (AndroidManifest)
`INTERNET`, `ACCESS_COARSE_LOCATION` (area), `RECORD_AUDIO` (dictation). No exact location, no contacts permission (the contact picker is a system picker), no background location.

## Revisit when
Push (Firebase adds a device token: "Device or other IDs" and "App activity") and any crash reporting (Sentry/Crashlytics) are turned on.
