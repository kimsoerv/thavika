-- Thavika: tables, security and sync rules.
-- Paste this whole file into Supabase > SQL Editor > New query > Run.
-- Run it once, on a new project.
--
-- Every table has the same shape as the table on the phone, in snake_case:
--   id            text         set by the phone (a UUID), so entries can be created offline
--   owner_id      uuid         the signed-in user who owns the row
--   household_id  uuid         reserved for shared households (Phase C)
--   updated_at    timestamptz  set by the phone on every change (last write wins)
--   deleted_at    timestamptz  soft delete, so deletes sync too
--   server_updated_at          set by the server; phones page through changes with it
--
-- Built-in categories (cat_food ...) are the same on every phone and are NOT synced.
-- Local-only things are not here either: the PIN, language, reminder settings.

create table public.categories (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  name text not null,
  icon text not null,
  kind text not null check (kind in ('expense', 'income')),
  group_name text not null default 'other',
  sort_order integer not null default 0,
  is_default boolean not null default false,
  is_hidden boolean not null default false,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.wallets (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  name text not null,
  icon text not null default 'wallet',
  kind text not null default 'cash',
  opening_minor bigint not null default 0,
  currency text not null,
  sort_order integer not null default 0,
  is_archived boolean not null default false,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.transactions (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  type text not null check (type in ('expense', 'income')),
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null,
  category_id text not null,
  note text not null default '',
  occurred_on date not null,
  created_by text,
  wallet_id text,
  receipt_path text,
  split_group text,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.transfers (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  from_wallet_id text not null,
  to_wallet_id text not null,
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null,
  occurred_on date not null,
  note text not null default '',
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.tags (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  name text not null,
  color_index integer not null default 0,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.transaction_tags (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  transaction_id text not null,
  tag_id text not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.plans (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  template text not null,
  income_minor bigint not null,
  currency text not null,
  is_active boolean not null default true,
  name text,
  active_from date,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.plan_items (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  plan_id text not null,
  group_name text not null,
  name text not null,
  category_id text,
  amount_minor bigint not null,
  is_fixed boolean not null default false,
  sort_order integer not null default 0,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.goals (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  name text not null,
  target_minor bigint not null,
  currency text not null,
  target_date date,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.goal_contributions (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  goal_id text not null,
  amount_minor bigint not null,
  occurred_on date not null,
  wallet_id text,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.recurring_rules (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  type text not null check (type in ('expense', 'income')),
  amount_minor bigint not null,
  currency text not null,
  category_id text not null,
  note text not null default '',
  frequency text not null check (frequency in ('weekly', 'monthly')),
  start_on date not null,
  next_run_on date not null,
  is_active boolean not null default true,
  is_bill boolean not null default false,
  auto_create boolean not null default true,
  remind_days_before integer not null default 2,
  wallet_id text,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.debts (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  person text not null,
  direction text not null check (direction in ('lent', 'borrowed')),
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null,
  note text not null default '',
  started_on date not null,
  due_on date,
  wallet_id text,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.debt_payments (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  debt_id text not null,
  amount_minor bigint not null check (amount_minor >= 0),
  occurred_on date not null,
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

create table public.challenges (
  id text primary key,
  owner_id uuid not null references auth.users (id) on delete cascade,
  household_id uuid,
  goal_id text not null,
  kind text not null check (kind in ('weekly', 'fixed')),
  unit_minor bigint not null,
  steps integer not null,
  start_on date not null,
  completed_steps text not null default '',
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);

-- Last write wins, decided by the phone's updated_at. An old edit that was
-- waiting offline can never overwrite a newer change: the update is skipped.
create function public.sync_guard() returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE' then
    if new.updated_at < old.updated_at then
      return null;
    end if;
    new.owner_id := old.owner_id;
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

do $$
declare
  t text;
begin
  foreach t in array array[
    'categories', 'wallets', 'transactions', 'transfers', 'tags',
    'transaction_tags', 'plans', 'plan_items', 'goals', 'goal_contributions',
    'recurring_rules', 'debts', 'debt_payments', 'challenges'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);

    execute format(
      'create policy "owner can read" on public.%I for select using (owner_id = auth.uid())', t);
    execute format(
      'create policy "owner can insert" on public.%I for insert with check (owner_id = auth.uid())', t);
    execute format(
      'create policy "owner can update" on public.%I for update using (owner_id = auth.uid()) with check (owner_id = auth.uid())', t);
    -- No delete policy: deletes are soft (deleted_at), so they sync.

    execute format(
      'create trigger %I before insert or update on public.%I for each row execute function public.sync_guard()',
      t || '_sync_guard', t);

    -- Phones page through changes ordered by (server_updated_at, id).
    execute format(
      'create index %I on public.%I (owner_id, server_updated_at, id)',
      t || '_sync_idx', t);
  end loop;
end;
$$;

-- Lets a signed-in user delete their account and everything they stored.
-- Required by the app stores. Rows are removed by "on delete cascade".
create function public.delete_my_account() returns void
language plpgsql
security definer
set search_path = public, auth
as $$
begin
  if auth.uid() is null then
    raise exception 'not signed in';
  end if;
  delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
