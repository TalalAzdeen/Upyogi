begin;

create table public.app_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'Customer' check (role in ('Customer', 'Provider')),
  created_at timestamptz not null default now()
);

create function public.create_app_profile()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.app_profiles(id, full_name, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'fullName', ''),
    case when new.raw_user_meta_data->>'role' = 'Provider' then 'Provider' else 'Customer' end);
  return new;
end;
$$;

create trigger create_app_profile_after_signup
after insert on auth.users for each row execute function public.create_app_profile();

create table public.wallet_accounts (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  currency text not null check (currency ~ '^[a-z]{3}$'),
  balance_minor bigint not null default 0 check (balance_minor >= 0),
  created_at timestamptz not null default now(),
  unique(owner_id, currency),
  unique(id, owner_id, currency)
);

create table public.wallet_topups (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null,
  owner_id uuid not null,
  currency text not null,
  amount_minor bigint not null check (amount_minor > 0),
  stripe_payment_intent_id text not null unique,
  status text not null default 'pending' check (status in ('pending', 'succeeded', 'cancelled', 'failed')),
  created_at timestamptz not null default now(),
  credited_at timestamptz,
  foreign key(wallet_id, owner_id, currency)
    references public.wallet_accounts(id, owner_id, currency)
);

create table public.wallet_ledger (
  id uuid primary key default gen_random_uuid(),
  wallet_id uuid not null references public.wallet_accounts(id),
  topup_id uuid not null unique references public.wallet_topups(id),
  amount_minor bigint not null check (amount_minor > 0),
  created_at timestamptz not null default now()
);

create table public.processed_payment_events (
  stripe_event_id text primary key,
  topup_id uuid not null unique references public.wallet_topups(id),
  processed_at timestamptz not null default now()
);

alter table public.app_profiles enable row level security;
alter table public.wallet_accounts enable row level security;
alter table public.wallet_topups enable row level security;
alter table public.wallet_ledger enable row level security;
alter table public.processed_payment_events enable row level security;

create policy profiles_read_own on public.app_profiles for select to authenticated
using (id = auth.uid());
create policy profiles_update_name on public.app_profiles for update to authenticated
using (id = auth.uid()) with check (id = auth.uid());
create policy wallets_read_own on public.wallet_accounts for select to authenticated
using (owner_id = auth.uid());
create policy topups_read_own on public.wallet_topups for select to authenticated
using (owner_id = auth.uid());
create policy ledger_read_own on public.wallet_ledger for select to authenticated
using (exists(select 1 from public.wallet_accounts w where w.id = wallet_id and w.owner_id = auth.uid()));

revoke all on public.app_profiles, public.wallet_accounts, public.wallet_topups,
  public.wallet_ledger, public.processed_payment_events from anon, authenticated;
grant select on public.app_profiles, public.wallet_accounts, public.wallet_topups,
  public.wallet_ledger to authenticated;
grant update(full_name) on public.app_profiles to authenticated;
grant all on public.app_profiles, public.wallet_accounts, public.wallet_topups,
  public.wallet_ledger, public.processed_payment_events to service_role;

-- Only a server that has verified Stripe's signed webhook may call this RPC.
-- All balance and ledger changes are committed atomically in one transaction.
create function public.credit_verified_topup(
  p_stripe_event_id text,
  p_payment_intent_id text,
  p_amount_minor bigint,
  p_currency text
) returns bigint language plpgsql security definer set search_path = public as $$
declare
  topup public.wallet_topups%rowtype;
  resulting_balance bigint;
begin
  if p_stripe_event_id is null or p_stripe_event_id = '' then
    raise exception 'Missing verified event ID';
  end if;
  select * into topup from public.wallet_topups
    where stripe_payment_intent_id = p_payment_intent_id for update;
  if not found then raise exception 'Unknown payment intent'; end if;
  if topup.amount_minor <> p_amount_minor or topup.currency <> p_currency then
    raise exception 'Payment amount or currency mismatch';
  end if;
  if topup.status = 'succeeded' then
    select balance_minor into resulting_balance from public.wallet_accounts where id = topup.wallet_id;
    return resulting_balance;
  end if;
  if topup.status <> 'pending' then raise exception 'Top-up is not pending'; end if;
  perform 1 from public.wallet_accounts where id = topup.wallet_id for update;
  insert into public.processed_payment_events(stripe_event_id, topup_id)
    values(p_stripe_event_id, topup.id);
  insert into public.wallet_ledger(wallet_id, topup_id, amount_minor)
    values(topup.wallet_id, topup.id, topup.amount_minor);
  update public.wallet_accounts set balance_minor = balance_minor + topup.amount_minor
    where id = topup.wallet_id returning balance_minor into resulting_balance;
  update public.wallet_topups set status = 'succeeded', credited_at = now() where id = topup.id;
  return resulting_balance;
end;
$$;

revoke all on function public.create_app_profile() from public, anon, authenticated;
revoke all on function public.credit_verified_topup(text, text, bigint, text) from public, anon, authenticated;
grant execute on function public.credit_verified_topup(text, text, bigint, text) to service_role;

commit;
