-- The urgent fee equals what one ordinary request costs the customer (20 EGP),
-- so asking for someone "now" doesn't cost more than asking at all.
alter table public.app_settings
  alter column urgent_fee_piastres set default 2000;

update public.app_settings set urgent_fee_piastres = 2000;
