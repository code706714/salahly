-- More categories, part 1: the new enum values. They live in their own
-- migration because a value added to an enum can't be used until the
-- transaction that added it has committed; part 2 uses them.

alter type public.request_issue add value if not exists 'carpentry_door';
alter type public.request_issue add value if not exists 'carpentry_furniture';
alter type public.request_issue add value if not exists 'carpentry_custom';
alter type public.request_issue add value if not exists 'tv_no_signal';
alter type public.request_issue add value if not exists 'tv_screen';
alter type public.request_issue add value if not exists 'tv_not_starting';
alter type public.request_issue add value if not exists 'aluminum_window';
alter type public.request_issue add value if not exists 'aluminum_door';
alter type public.request_issue add value if not exists 'aluminum_glass';
