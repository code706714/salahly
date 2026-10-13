-- Run this file on its own, before 20261014090100_voice_calls.sql: a new
-- enum value can't be used in the transaction that adds it.

alter type public.notification_kind add value if not exists 'incoming_call';
