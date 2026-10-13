-- Run this file on its own, before 20261013110100_escrow.sql: a new enum
-- value can't be used in the transaction that adds it.

-- The consumer's money is held (to her and to the technician), refused,
-- released to the technician, paid out, disputed or refunded.
alter type public.notification_kind add value if not exists 'escrow_held';
alter type public.notification_kind add value if not exists 'escrow_rejected';
alter type public.notification_kind add value if not exists 'escrow_released';
alter type public.notification_kind add value if not exists 'escrow_paid_out';
alter type public.notification_kind add value if not exists 'escrow_disputed';
alter type public.notification_kind add value if not exists 'escrow_refunded';
