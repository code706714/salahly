-- Run this file on its own, before 20261013090100_urgent_requests.sql: a new
-- enum value can't be used in the transaction that adds it.

alter type public.notification_kind add value if not exists 'urgent_request';
