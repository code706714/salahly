# Admin console: setup and operations

The admin console is an internal, online-only web app for the platform team.
Its backend is the migration `20261007090000_admin_console.sql`: a fixed list
of `public.admin_*` functions, each of which refuses anyone who is not in
`private.admins`. Nothing in the API can add an admin: the table has no
grants, no policies, and no function writes to it. An admin is added by hand
from a database session.

## Adding an admin

1. The person signs in to the app once with their phone (WhatsApp OTP) so an
   `auth.users` row exists. (Or create the user in the Supabase dashboard,
   Authentication, Users.)
2. In the Supabase SQL editor (runs as `postgres`), or `psql` with the
   database owner:

   ```sql
   insert into private.admins (user_id, note)
   select id, 'Amr (owner)' from auth.users where phone = '2010XXXXXXXX';
   ```

   The phone in `auth.users` has no `+`. Check the row landed:

   ```sql
   select a.user_id, u.phone, a.note, a.created_at
     from private.admins a join auth.users u on u.id = a.user_id;
   ```

3. After signing in again, `select guard.is_admin();` is true for that
   session, and the console's functions work.

## Removing an admin

```sql
delete from private.admins where user_id = '<uuid>';
```

Deleting an admin's account (`delete_my_account`) removes them too. Their
past actions stay in the audit log (it has no foreign key to the user).

## Rules the backend enforces

- Every admin function starts with the admin check (`admin_required`,
  SQLSTATE 42501 otherwise) and has an empty `search_path`. `anon` can not
  execute any of them.
- Lists are paged: `p_limit` defaults to 50 and is capped at 100,
  `p_offset` at 100000. Filters and searches are validated (`invalid_filter`,
  `invalid_search`, `invalid_value`, `invalid_reason`, SQLSTATE 22023).
- **Recent login** (`recent_login_required`, SQLSTATE P0001): reviewing a
  transfer (approve or reject), changing free uses or the target, prices,
  and payment accounts need a login made in the last 15 minutes, judged the
  same way as `delete_my_account` (the `amr` timestamp in the token, else
  `iat`). The console should send the admin through the OTP login again and
  retry when it sees this error.
- **Audit log**: every admin action, and every time an admin opens a
  technician's ID photos, adds a row to `private.admin_audit_log` (who, what,
  target, details, time). Rows can not be updated, deleted or truncated (a
  trigger refuses, even for the database owner, until the trigger is dropped
  on purpose). No API role can read the table; admins read it through
  `admin_list_audit_log`. Read it from SQL with:

  ```sql
  select created_at, admin_id, action, target_type, target_id, details
    from private.admin_audit_log order by id desc limit 100;
  ```

- **Files**: an admin can read (and create signed URLs for) objects in the
  buckets `transfer-proofs`, `verification-docs` and `request-photos`, and
  nothing else. Use the admin's own session to call
  `storage.from(bucket).createSignedUrl(path, 60)` with the path the function
  returned; keep the expiry short.
- Text written by users (complaint details, names) comes back verbatim:
  the console must render it as text, never as HTML.

## Suspending someone

`admin_suspend_user` sets `profiles.suspended_at` and records the reason (for
the team) in `private.suspensions`. From then on every function the app uses
to write refuses the account with `account_suspended` (SQLSTATE 42501), uploads
are refused by the storage policies, a suspended technician gets no new
requests and is not counted as verified, a consumer's open requests are
cancelled (their use comes back), and a waiting offer of a suspended
technician can not be accepted. Reading is still allowed, and so is deleting
one's own account; a hash of the phone is kept so signing up again with the
same number starts suspended. `admin_restore_user` lifts it, including for
that number.

The person can read their own `profiles.suspended_at`, so the app can show a
"your account is suspended" screen on seeing `account_suspended`.

This does not block signing in or refreshing the token (so the app can show
that screen and the person can still delete their account). If a hard
block at the auth layer is ever wanted, also set `auth.users.banned_until`.

## Hosted project checklist (not reachable from code)

- Turn on MFA for the admin accounts if the dashboard login allows it, and
  keep the admin list short.
- Keep the Twilio Verify geo permissions and rate limits from the backend
  security rules: admins sign in by the same OTP.
- Never put a service-role key in the console. It talks to the API with the
  admin's own session only.
