-- Run this file on its own, before 20261013150100_referrals.sql: a new enum
-- value can't be used in the transaction that adds it.

alter type public.ledger_reason add value if not exists 'referral_reward';
