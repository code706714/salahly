# Online payments

Every payment in Salahly (a pack of uses, and the consumer's payment for a
request) goes through one server-side payment service. The Flutter apps
never talk to the payment provider and never decide that money arrived.

## What is paid for

| Purpose | Who | What happens when the provider confirms |
| --- | --- | --- |
| `credit_pack` | consumer (requests) or technician (jobs) | the uses are added to the balance once, with a `credit_ledger` row that points at the order |
| `escrow` | consumer, for a request with an agreed price | an `escrow` row is created as `held` (see "Escrow, honestly") |

The amount is always decided on the server: the pack price from
`credit_packs`, the request price from the accepted offer. The app sends the
price it saw (`expected_price_piastres`); if the pack now costs something
else the server refuses with `price_changed` and nothing is charged.

## Flow

1. The app calls the edge function `payment-create` with the signed-in
   user's JWT (`{purpose:"credit_pack", pack_id, expected_price_piastres}` or
   `{purpose:"escrow", request_id}`).
2. The database creates a `payment_orders` row (`created`, amount and
   currency fixed) through `create_credit_pack_payment` /
   `create_escrow_payment`, rate limited per user.
3. The provider adapter creates the checkout; the function returns
   `{order_id, checkout_url, amount_piastres}`. The app only opens an
   `https` URL.
4. The person pays on the provider's page (card, or a mobile wallet such as
   Vodafone Cash, which can stay pending until they approve on their phone).
5. The provider calls `payment-webhook?provider=paymob`. The HMAC is
   verified, the transaction is normalised and handed to
   `payments_apply_event`, which:
   - ignores a repeated event (`payment_events` is unique on
     `(provider, event_key)`),
   - never moves an order backwards (a late `pending` can not undo
     `succeeded`),
   - checks the amount and currency against the order (a mismatch is
     recorded and never fulfils),
   - on the first valid `succeeded`, fulfils exactly once (credits or
     escrow), notifies the user, and sets `fulfilled_at`.
6. When the provider has an inquiry API (`PAYMOB_API_KEY`), a success is
   double checked with the provider before fulfilling.
7. The app polls its own order (`payment_orders`, RLS: own rows only) and
   shows "paid" only when the server says `succeeded`. Closing the screen
   does not cancel anything: the payment still completes on the server.
8. `payment-reconcile` runs every 10 minutes (pg_cron) and asks the provider
   about orders that are still open, so a lost webhook does not leave money
   taken and nothing granted. Orders that were never paid expire.

A redirect, a success page or any client call is never proof of payment.

## Code map

- Database: `supabase/migrations/20261015100000_payments.sql`
  (`payment_orders`, `payment_attempts`, `payment_events`, the RPCs above,
  `admin_list_payments`, `payments_record_refund`).
- Edge functions: `payment-create`, `payment-webhook`, `payment-reconcile`,
  `payment-refund`, and `_shared/payments/` (`gateway.ts` interface,
  `paymob.ts` adapter, `registry.ts`, `service.ts` provider-independent
  logic, `supabase_db.ts`).
- Flutter: `lib/features/payments/` (repository, `PaymentCubit`,
  `PaymentPage`), used by `BuyUsesCubit` and `SecurePaymentCubit`.

## Switching provider

The app, the SQL and `service.ts` know nothing about Paymob. To add or
switch a provider (for example PayTabs):

1. Write `<provider>.ts` implementing `PaymentGateway`
   (`createCheckout`, `verifyWebhook`, `fetchPayment`, `canInquire`,
   `refund`) and map its statuses to the normalised ones.
2. Register it in `registry.ts` and set `PAYMENT_PROVIDER=<provider>`.
3. Set its secrets and point its webhook at
   `.../payment-webhook?provider=<provider>`.
4. `payment_orders.provider` is plain text (3 to 20 lowercase letters), so
   no migration is needed. Add adapter tests like `paymob_test.ts`.

Orders keep the provider they were created with, so orders in flight finish
with the old provider while new ones use the new one. A switch does touch the
adapter, its secrets, and the dashboard webhook; it does not touch screens or
business logic.

## Secrets and settings for real payments

Edge function secrets (Supabase dashboard, Edge Functions, Secrets). None of
these are in the repository or the app:

| Secret | Meaning |
| --- | --- |
| `PAYMENT_PROVIDER` | `paymob` (default) |
| `PAYMOB_SECRET_KEY` | Paymob secret key (creates intentions) |
| `PAYMOB_PUBLIC_KEY` | Paymob public key (checkout page) |
| `PAYMOB_HMAC_SECRET` | verifies webhooks |
| `PAYMOB_INTEGRATION_IDS` | comma separated integration ids, card and wallet (use the **test** ids for sandbox) |
| `PAYMOB_API_KEY` | optional: enables inquiry (double check, reconcile) and API refunds |
| `PAYMENT_RECONCILE_SECRET` | at least 32 random characters, shared with the cron job |
| `PAYMENT_RETURN_URL` | optional: where Paymob sends the browser afterwards |

Database (Vault), so the cron job can call the reconcile function:

```sql
select vault.create_secret('https://<project>.supabase.co/functions/v1/payment-reconcile', 'payment_reconcile_url');
select vault.create_secret('<same value as PAYMENT_RECONCILE_SECRET>', 'payment_reconcile_secret');
```

Paymob dashboard:

- Set the **Transaction processed callback** of every integration you use
  (card and wallet separately) to
  `https://<project>.supabase.co/functions/v1/payment-webhook?provider=paymob`.
  The wallet integration needs its own callback, otherwise a wallet payment
  would stay pending until reconciliation.
- Enable the mobile wallet integration on the merchant account.
- Use test mode keys and integrations until the account is approved.

Deploy:

```sh
supabase db push
supabase functions deploy payment-create payment-webhook payment-reconcile payment-refund
```

`payment-webhook` and `payment-reconcile` are deployed with
`verify_jwt = false` (see `supabase/config.toml`); they authenticate by the
provider's HMAC and by the shared reconcile secret instead.

Until the secrets are set, `payment-create` answers `payments_not_configured`
and the app says that online payment is not available. Nothing is simulated.

## Escrow, honestly

A normal payment gateway does not hold money for a third party and release
it on a condition. What Salahly does today:

- The consumer's money is **paid to Salahly's own merchant account**, and
  only after the provider confirmed it does the app show the payment as
  recorded ("held" in our books).
- The work is confirmed on **both sides** in "follow your request": the
  customer (`confirm_work_done`) and the technician
  (`technician_confirm_work_done`, once the job is finished). Either side can
  press a complaint instead, which puts the payment in `disputed`.
- When both confirmed, the money is scheduled to reach the technician's
  **in-app wallet 3 days later** (`job_escrows.release_at`) if nobody
  disputed. A technician confirmation with a silent customer also releases
  after 3 days. `private.release_due_escrows` (pg_cron) credits the wallet
  and the status becomes `paid_out`. Both sides are told what happens next.
- The technician **withdraws from the wallet** to a Vodafone Cash number or
  an InstaPay address he types (`request_withdrawal`, minimum 50 EGP, no
  fee, 5 requests per day). The amount leaves the wallet at once. **Sending
  the money is still a manual transfer** by the Salahly team from the admin
  console (Withdrawals): paid (with the transfer reference) or rejected
  (the amount returns to the wallet).
- A dispute is settled by the team; a refund goes back through the provider.

This is **not** a regulated escrow or a segregated client-money account. Do
not describe it to users as such. Calling it escrow, holding funds for
technicians and paying them out may need a licence, a licensed partner, or
Paymob approval for split/marketplace payouts and a suitable merchant
category. Get a legal and commercial review before launch. The states in the
app are only the ones the server can prove: payment confirmed by the provider,
work confirmed, owed, paid out, refund due, refunded.

## Refunds

- `refund_due` escrows (the request was cancelled, or the job is no longer
  going ahead) are returned from the admin console: **refund through the
  provider** calls `payment-refund` (admin with a recent login only). If the
  merchant account can not refund by API, it answers `refund_by_dashboard`:
  refund from the Paymob dashboard and the refunded webhook closes the escrow.
- Pack payments have no self service refund; use the provider dashboard and
  an admin balance adjustment if needed.

## Old manual transfers (legacy)

InstaPay / wallet transfers with a screenshot are closed to new use:
`submit_topup` and `secure_payment` are no longer executable by
`authenticated`. Old rows and the admin review screens are kept so pending
transfers can still be approved or rejected, and history stays visible.

Rollback: to reopen the manual flow, run
`grant execute on function public.submit_topup, public.secure_payment to authenticated;`
(the old app screens are gone, so this only helps an older app build).

## Before real money

- Paymob merchant account approved for live (commercial register, tax card,
  bank account verification as Paymob asks), wallet integration enabled.
- Live keys, integration ids, HMAC and callbacks set as above.
- Test a small card and a wallet payment end to end, plus a refund and a
  withdrawal (request, mark paid, reject).
- Legal review of the escrow wording, the terms and the privacy policy
  (payment data is handled by the provider; we keep order status, amount and
  provider references only).
