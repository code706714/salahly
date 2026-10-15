-- Run this file on its own, before 20261015110100_wallet.sql: a new enum
-- value can't be used in the transaction that adds it.

-- The other side confirmed the work; both confirmed, so the money is
-- scheduled for the technician's wallet; a withdrawal was paid or refused.
alter type public.notification_kind add value if not exists 'escrow_work_confirmed';
alter type public.notification_kind add value if not exists 'escrow_release_scheduled';
alter type public.notification_kind add value if not exists 'withdrawal_paid';
alter type public.notification_kind add value if not exists 'withdrawal_rejected';
