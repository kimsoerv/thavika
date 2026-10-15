-- Thavika: households (shared entries, plan, goals ...).
-- Paste this whole file into Supabase > SQL Editor > New query > Run,
-- after 0001_init.sql. Run it once.
--
-- How sharing works
--   * A household has members. Everything a member has (entries, wallets,
--     plan, goals ...) carries the household's id in `household_id` and every
--     member can read and change it. Who made a row stays in `owner_id`.
--   * A person is in at most one household.
--   * All changes to households go through the functions at the bottom, so the
--     rules cannot be bypassed from the app.
--   * Rows keep their household when their author leaves: the household keeps
--     what it was given. The leaver can no longer see them. (The app gives the
--     leaver a personal copy of their own entries and the plan.)

------------------------------------------------------------------------
-- Tables
------------------------------------------------------------------------

create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  owner_id uuid not null references auth.users (id),
  created_at timestamptz not null default now()
);

create table public.household_members (
  household_id uuid not null references public.households (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member' check (role in ('owner', 'member')),
  display_name text,
  joined_at timestamptz not null default now(),
  primary key (household_id, user_id),
  unique (user_id)
);

create table public.household_invites (
  code text primary key,
  household_id uuid not null references public.households (id) on delete cascade,
  created_by uuid not null references auth.users (id) on delete cascade,
  expires_at timestamptz not null
);

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------

-- The tables that hold a user's data and are shared with a household.
create function public.synced_tables() returns text[]
language sql immutable
as $$
  select array[
    'categories', 'wallets', 'transactions', 'transfers', 'tags',
    'transaction_tags', 'plans', 'plan_items', 'goals', 'goal_contributions',
    'recurring_rules', 'debts', 'debt_payments', 'challenges'
  ];
$$;

create function public.is_household_member(hid uuid) returns boolean
language sql stable security definer set search_path = public
as $$
  select hid is not null and exists (
    select 1 from public.household_members
    where household_id = hid and user_id = auth.uid()
  );
$$;

create function public.my_household_id() returns uuid
language sql stable security definer set search_path = public
as $$
  select household_id from public.household_members
  where user_id = auth.uid() limit 1;
$$;

------------------------------------------------------------------------
-- Last write wins, owner and household protected
------------------------------------------------------------------------

-- Replaces the guard from 0001. On a normal edit:
--   * an older edit is ignored (last write wins),
--   * the author (owner_id) and the household cannot be changed,
-- and a new row of a household member joins the household by itself.
-- The functions below switch the protection off for their own changes with
-- the setting thavika.admin.
create or replace function public.sync_guard() returns trigger
language plpgsql
as $$
declare
  admin boolean := coalesce(current_setting('thavika.admin', true), '') = '1';
begin
  if tg_op = 'UPDATE' then
    if not admin then
      if new.updated_at < old.updated_at then
        return null;
      end if;
      new.owner_id := old.owner_id;
      new.household_id := old.household_id;
    end if;
  elsif tg_op = 'INSERT' then
    if not admin and new.household_id is null then
      new.household_id := public.my_household_id();
    end if;
  end if;
  new.server_updated_at := clock_timestamp();
  return new;
end;
$$;

------------------------------------------------------------------------
-- Security rules
------------------------------------------------------------------------

alter table public.households enable row level security;
alter table public.household_members enable row level security;
alter table public.household_invites enable row level security;

create policy "members can read" on public.households for select
  using (public.is_household_member(id));

create policy "members can read" on public.household_members for select
  using (public.is_household_member(household_id));

-- household_invites: no policy, so nobody reads it directly.

-- Data tables: personal rows belong to their owner; household rows belong to
-- every member.
do $$
declare
  t text;
begin
  foreach t in array public.synced_tables()
  loop
    execute format('drop policy "owner can read" on public.%I', t);
    execute format('drop policy "owner can insert" on public.%I', t);
    execute format('drop policy "owner can update" on public.%I', t);

    execute format($f$
      create policy "personal or household read" on public.%I for select using (
        (household_id is null and owner_id = auth.uid())
        or public.is_household_member(household_id))
    $f$, t);

    execute format($f$
      create policy "own or household insert" on public.%I for insert with check (
        owner_id = auth.uid()
        and (household_id is null or public.is_household_member(household_id)))
    $f$, t);

    execute format($f$
      create policy "personal or household update" on public.%I for update
      using (
        (household_id is null and owner_id = auth.uid())
        or public.is_household_member(household_id))
      with check (
        (household_id is null and owner_id = auth.uid())
        or public.is_household_member(household_id))
    $f$, t);
  end loop;
end;
$$;

-- Household members get changes quickly through Supabase Realtime.
do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array public.synced_tables()
    loop
      execute format('alter publication supabase_realtime add table public.%I', t);
    end loop;
  end if;
end;
$$;

------------------------------------------------------------------------
-- Internal functions (not callable from the app)
------------------------------------------------------------------------

-- Puts all of a user's personal rows into a household.
create function public._share_rows(uid uuid, hid uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare
  t text;
begin
  perform set_config('thavika.admin', '1', true);

  -- One plan for the household: if it already has one, the newcomer's plans
  -- move to their plan library (they are kept, but no month uses them).
  if exists (
    select 1 from public.plans
    where household_id = hid and active_from is not null and deleted_at is null
  ) then
    update public.plans set active_from = null, updated_at = now()
    where owner_id = uid and household_id is null and active_from is not null;
  end if;

  foreach t in array public.synced_tables()
  loop
    execute format(
      'update public.%I set household_id = $1 where owner_id = $2 and household_id is null',
      t) using hid, uid;
  end loop;

  perform set_config('thavika.admin', '', true);
end;
$$;

-- Removes a user from their household. Returns 'none' (was in none),
-- 'left' (the household goes on) or 'dissolved' (the user was the last one:
-- the household ends and everything in it becomes the user's own).
-- A household's rows made by the leaver stay with the household.
create function public._leave(uid uuid, out result text, out hid uuid, out new_owner uuid)
language plpgsql security definer set search_path = public
as $$
declare
  was_owner boolean;
  t text;
begin
  select m.household_id, m.role = 'owner' into hid, was_owner
  from public.household_members m where m.user_id = uid;
  if hid is null then
    result := 'none';
    return;
  end if;

  delete from public.household_members where user_id = uid;

  select m.user_id into new_owner
  from public.household_members m
  where m.household_id = hid
  order by m.joined_at, m.user_id limit 1;

  if new_owner is null then
    -- Last member: the household ends. Everything in it becomes personal
    -- data of this user, so nothing is lost.
    perform set_config('thavika.admin', '1', true);
    foreach t in array public.synced_tables()
    loop
      execute format(
        'update public.%I set household_id = null, owner_id = $1 where household_id = $2',
        t) using uid, hid;
    end loop;
    perform set_config('thavika.admin', '', true);
    delete from public.households where id = hid;
    result := 'dissolved';
    return;
  end if;

  if was_owner then
    update public.households set owner_id = new_owner where id = hid;
    update public.household_members set role = 'owner'
    where household_id = hid and user_id = new_owner;
  end if;
  result := 'left';
end;
$$;

revoke all on function public._share_rows(uuid, uuid) from public, anon, authenticated;
revoke all on function public._leave(uuid) from public, anon, authenticated;

------------------------------------------------------------------------
-- Functions the app calls
------------------------------------------------------------------------

-- Starts a household with the caller as owner and shares all their data.
create function public.create_household(p_name text, p_display_name text default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if public.my_household_id() is not null then
    raise exception 'already in a household';
  end if;
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'a household needs a name';
  end if;

  insert into public.households (name, owner_id) values (trim(p_name), uid)
  returning id into hid;
  insert into public.household_members (household_id, user_id, role, display_name)
  values (hid, uid, 'owner', nullif(trim(coalesce(p_display_name, '')), ''));

  perform public._share_rows(uid, hid);
  return hid;
end;
$$;

-- A code the owner gives to a new member. Valid for 7 days.
create function public.create_invite() returns text
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
  new_code text;
begin
  if uid is null then raise exception 'not signed in'; end if;
  select m.household_id into hid
  from public.household_members m where m.user_id = uid and m.role = 'owner';
  if hid is null then raise exception 'only the owner can invite'; end if;

  delete from public.household_invites where expires_at < now();
  new_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
  insert into public.household_invites (code, household_id, created_by, expires_at)
  values (new_code, hid, uid, now() + interval '7 days');
  return new_code;
end;
$$;

-- Joins with a code and shares all the caller's data with the household.
create function public.join_household(p_code text, p_display_name text default null)
returns uuid
language plpgsql security definer set search_path = public
as $$
declare
  uid uuid := auth.uid();
  hid uuid;
begin
  if uid is null then raise exception 'not signed in'; end if;
  if public.my_household_id() is not null then
    raise exception 'already in a household';
  end if;

  select i.household_id into hid
  from public.household_invites i
  where i.code = upper(trim(coalesce(p_code, ''))) and i.expires_at > now();
  if hid is null then raise exception 'invalid or expired code'; end if;

  insert into public.household_members (household_id, user_id, role, display_name)
  values (hid, uid, 'member', nullif(trim(coalesce(p_display_name, '')), ''));

  perform public._share_rows(uid, hid);
  return hid;
end;
$$;

-- The caller leaves. Returns 'left' or 'dissolved' (see _leave).
create function public.leave_household() returns text
language plpgsql security definer set search_path = public
as $$
declare
  r record;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select * into r from public._leave(auth.uid());
  return r.result;
end;
$$;

-- The owner removes a member.
create function public.remove_member(p_user uuid) returns void
language plpgsql security definer set search_path = public
as $$
declare
  hid uuid;
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  select m.household_id into hid
  from public.household_members m where m.user_id = auth.uid() and m.role = 'owner';
  if hid is null then raise exception 'only the owner can remove members'; end if;
  if p_user = auth.uid() then raise exception 'use leave instead'; end if;
  if not exists (
    select 1 from public.household_members
    where household_id = hid and user_id = p_user
  ) then
    raise exception 'not a member';
  end if;
  perform public._leave(p_user);
end;
$$;

create function public.rename_household(p_name text) returns void
language plpgsql security definer set search_path = public
as $$
begin
  if p_name is null or length(trim(p_name)) = 0 then
    raise exception 'a household needs a name';
  end if;
  update public.households h set name = trim(p_name)
  where h.owner_id = auth.uid();
  if not found then raise exception 'only the owner can rename'; end if;
end;
$$;

revoke all on function public.create_household(text, text) from public, anon;
revoke all on function public.create_invite() from public, anon;
revoke all on function public.join_household(text, text) from public, anon;
revoke all on function public.leave_household() from public, anon;
revoke all on function public.remove_member(uuid) from public, anon;
revoke all on function public.rename_household(text) from public, anon;
grant execute on function public.create_household(text, text) to authenticated;
grant execute on function public.create_invite() to authenticated;
grant execute on function public.join_household(text, text) to authenticated;
grant execute on function public.leave_household() to authenticated;
grant execute on function public.remove_member(uuid) to authenticated;
grant execute on function public.rename_household(text) to authenticated;

------------------------------------------------------------------------
-- Deleting an account no longer takes the household's data with it
------------------------------------------------------------------------

create or replace function public.delete_my_account() returns void
language plpgsql security definer set search_path = public, auth
as $$
declare
  uid uuid := auth.uid();
  r record;
  t text;
begin
  if uid is null then
    raise exception 'not signed in';
  end if;

  select * into r from public._leave(uid);
  if r.result = 'left' then
    -- Entries the user added to a household that goes on stay with it.
    perform set_config('thavika.admin', '1', true);
    foreach t in array public.synced_tables()
    loop
      execute format(
        'update public.%I set owner_id = $1 where owner_id = $2 and household_id = $3',
        t) using r.new_owner, uid, r.hid;
    end loop;
    perform set_config('thavika.admin', '', true);
  end if;

  delete from auth.users where id = uid;
end;
$$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
