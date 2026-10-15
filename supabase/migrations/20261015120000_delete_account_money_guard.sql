-- Deleting an account must not eat money. The wallet, the withdrawals and the
-- held escrows were added after delete_my_account, which knew nothing of them:
-- a technician's balance or pending withdrawal vanished with the account (their
-- rows cascade), and an escrow that still had to be released or refunded lost
-- both of its people and could never be settled.
--
-- The original function keeps doing the deleting; this wrapper refuses first
-- while the person has money in any of those states.

alter function public.delete_my_account(text) set schema private;
alter function private.delete_my_account(text) rename to delete_my_account_core;
revoke execute on function private.delete_my_account_core(text) from public, anon, authenticated;

create function public.delete_my_account(p_confirmation text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
begin
  if v_user_id is null then
    raise exception 'not_signed_in' using errcode = '28000';
  end if;

  if exists (
       select 1 from public.technician_wallets
        where technician_id = v_user_id and balance_piastres > 0
     )
     or exists (
       select 1 from public.wallet_withdrawals
        where technician_id = v_user_id and status = 'requested'
     )
     or exists (
       select 1 from public.job_escrows
        where (consumer_id = v_user_id or technician_id = v_user_id)
          and status in ('held', 'disputed', 'refund_due')
     ) then
    raise exception 'money_open' using errcode = 'P0001';
  end if;

  perform private.delete_my_account_core(p_confirmation);
end;
$$;

revoke execute on function public.delete_my_account(text) from public, anon;
grant execute on function public.delete_my_account(text) to authenticated;
