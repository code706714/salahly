-- Run this file on its own, before 20261013100100_request_chat.sql: a new
-- enum value can't be used in the transaction that adds it.

alter type public.notification_kind add value if not exists 'chat_message';
