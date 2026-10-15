-- Run this file on its own, before 20261015130100_admin_activity.sql: a new
-- enum value can't be used in the transaction that adds it.

-- The team answered the consumer's complaint.
alter type public.notification_kind add value if not exists 'complaint_resolved';
