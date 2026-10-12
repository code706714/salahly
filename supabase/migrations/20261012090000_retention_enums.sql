-- Run this file on its own, before 20261012090100_retention.sql: a new enum
-- value can't be used in the transaction that adds it.

alter type public.notification_kind add value if not exists 'loyalty_reward';
alter type public.notification_kind add value if not exists 'maintenance_reminder';
alter type public.ledger_reason add value if not exists 'loyalty_reward';
