-- Marketplace v2, part 1: the new enum values. They live in their own
-- migration because a value added to an enum can't be used until the
-- transaction that added it has committed; part 2 uses them.

-- One issue list per service category (part 2 says which belong where).
alter type public.request_issue add value if not exists 'plumbing_leak';
alter type public.request_issue add value if not exists 'plumbing_clog';
alter type public.request_issue add value if not exists 'plumbing_mixer';
alter type public.request_issue add value if not exists 'plumbing_heater';
alter type public.request_issue add value if not exists 'plumbing_low_pressure';
alter type public.request_issue add value if not exists 'electrical_no_power';
alter type public.request_issue add value if not exists 'electrical_short';
alter type public.request_issue add value if not exists 'electrical_outlet';
alter type public.request_issue add value if not exists 'electrical_lighting';
alter type public.request_issue add value if not exists 'electrical_panel';
alter type public.request_issue add value if not exists 'washer_not_spinning';
alter type public.request_issue add value if not exists 'washer_not_draining';
alter type public.request_issue add value if not exists 'washer_leaking';
alter type public.request_issue add value if not exists 'washer_noisy';
alter type public.request_issue add value if not exists 'washer_not_starting';
alter type public.request_issue add value if not exists 'fridge_not_cooling';
alter type public.request_issue add value if not exists 'fridge_ice_buildup';
alter type public.request_issue add value if not exists 'fridge_noisy';
alter type public.request_issue add value if not exists 'fridge_leaking';
alter type public.request_issue add value if not exists 'fridge_door_seal';

-- A technician takes back an offer.
alter type public.offer_status add value if not exists 'withdrawn';

-- Price talks. To the technician: the consumer countered. To the consumer:
-- the technician lowered the price, took the offer back, or accepted the
-- consumer's price (which also picks them).
alter type public.notification_kind add value if not exists 'offer_countered';
alter type public.notification_kind add value if not exists 'offer_revised';
alter type public.notification_kind add value if not exists 'offer_withdrawn';
alter type public.notification_kind add value if not exists 'counter_accepted';
