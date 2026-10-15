-- Checks the household rules of 0002_households.sql.
-- Runs after stubs.sql, 0001_init.sql and 0002_households.sql (see run.sh).
-- Any failed check stops the run with its label.

create schema test;
grant usage on schema test to authenticated, anon;

create function test.check(label text, ok boolean) returns void
language plpgsql as $$
begin
  if ok is not true then raise exception 'FAILED: %', label; end if;
end $$;

-- The statement must fail (with an error or a permission problem).
create function test.fails(label text, stmt text) returns void
language plpgsql as $$
begin
  begin
    execute stmt;
  exception when others then
    return;
  end;
  raise exception 'FAILED (it worked, but should not): %', label;
end $$;

-- The statement must change nothing visible to the caller (0 rows).
create function test.rows(label text, stmt text, expected bigint) returns void
language plpgsql as $$
declare n bigint;
begin
  execute 'select count(*) from (' || stmt || ') s' into n;
  if n <> expected then
    raise exception 'FAILED: % (expected % rows, got %)', label, expected, n;
  end if;
end $$;

insert into auth.users (id, email) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'alice@example.com'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'bob@example.com'),
  ('cccccccc-0000-0000-0000-000000000003', 'carol@example.com'),
  ('dddddddd-0000-0000-0000-000000000004', 'dave@example.com'),
  ('eeeeeeee-0000-0000-0000-000000000005', 'eve@example.com');

\set as_alice 'select set_config(''request.jwt.claim.sub'', ''aaaaaaaa-0000-0000-0000-000000000001'', false); set role authenticated;'
\set as_bob   'select set_config(''request.jwt.claim.sub'', ''bbbbbbbb-0000-0000-0000-000000000002'', false); set role authenticated;'
\set as_carol 'select set_config(''request.jwt.claim.sub'', ''cccccccc-0000-0000-0000-000000000003'', false); set role authenticated;'
\set as_dave  'select set_config(''request.jwt.claim.sub'', ''dddddddd-0000-0000-0000-000000000004'', false); set role authenticated;'
\set as_eve   'select set_config(''request.jwt.claim.sub'', ''eeeeeeee-0000-0000-0000-000000000005'', false); set role authenticated;'

-- A row the way the phone uploads it: insert, or update when it exists.
create function test.put_tx(p_id text, p_owner uuid, p_amount bigint,
                            p_updated timestamptz, p_household uuid default null)
returns void language sql as $$
  insert into public.transactions
    (id, owner_id, household_id, type, amount_minor, currency, category_id,
     occurred_on, updated_at)
  values (p_id, p_owner, p_household, 'expense', p_amount, 'USD', 'cat_food',
          current_date, p_updated)
  on conflict (id) do update set
    owner_id = excluded.owner_id,
    household_id = excluded.household_id,
    amount_minor = excluded.amount_minor,
    updated_at = excluded.updated_at;
$$;

------------------------------------------------------------------------
-- 1. Personal data stays personal
------------------------------------------------------------------------
:as_alice
select test.put_tx('tx-alice-1', 'aaaaaaaa-0000-0000-0000-000000000001', 1000, now());
select test.rows('alice sees her row', 'select 1 from public.transactions', 1);
reset role;

:as_bob
select test.rows('bob does not see alice''s row', 'select 1 from public.transactions', 0);
select test.fails('bob cannot write as alice',
  $$select test.put_tx('tx-fake', 'aaaaaaaa-0000-0000-0000-000000000001', 1, now())$$);
select test.put_tx('tx-bob-1', 'bbbbbbbb-0000-0000-0000-000000000002', 500, now());
select test.rows('bob sees only his row', 'select 1 from public.transactions', 1);
reset role;

------------------------------------------------------------------------
-- 2. Alice starts a household; her data joins it
------------------------------------------------------------------------
select server_updated_at as before_share from public.transactions where id = 'tx-alice-1' \gset
select pg_sleep(0.01);

:as_alice
select public.create_household('Home', 'Alice') as hid \gset
select test.check('her row is in the household',
  (select household_id = :'hid' from public.transactions where id = 'tx-alice-1'));
select test.check('members can read the household',
  (select count(*) = 1 from public.households));
select test.fails('second household is refused', $$select public.create_household('Two')$$);
select public.create_invite() as code \gset
reset role;

select test.check('sharing bumps server_updated_at so phones pull the change',
  (select server_updated_at > :'before_share'::timestamptz from public.transactions where id = 'tx-alice-1'));

------------------------------------------------------------------------
-- 3. Bob joins; both see everything
------------------------------------------------------------------------
:as_bob
select test.fails('wrong code', $$select public.join_household('NOPE1234')$$);
select test.fails('non-owner cannot invite', $$select public.create_invite()$$);
select public.join_household(:'code', 'Bob') as bob_hid \gset
select test.check('bob joined alice''s household', :'bob_hid' = :'hid');
select test.rows('bob sees alice and himself', 'select 1 from public.transactions', 2);
select test.rows('bob sees the member list', 'select 1 from public.household_members', 2);
select test.fails('already in a household', $$select public.join_household('whatever')$$);
reset role;

:as_alice
select test.rows('alice sees both rows', 'select 1 from public.transactions', 2);
reset role;

------------------------------------------------------------------------
-- 4. Editing together
------------------------------------------------------------------------
:as_bob
-- Bob edits Alice's entry the way his phone would (owner_id = himself).
select test.put_tx('tx-alice-1', 'bbbbbbbb-0000-0000-0000-000000000002', 2000, now() + interval '1 minute');
select test.check('the edit went through', (select amount_minor = 2000 from public.transactions where id = 'tx-alice-1'));
select test.check('the author stays alice',
  (select owner_id = 'aaaaaaaa-0000-0000-0000-000000000001' from public.transactions where id = 'tx-alice-1'));
-- An older edit is ignored.
select test.put_tx('tx-alice-1', 'bbbbbbbb-0000-0000-0000-000000000002', 7, now() - interval '1 day');
select test.check('an older edit is ignored', (select amount_minor = 2000 from public.transactions where id = 'tx-alice-1'));
-- Trying to unshare does nothing.
select test.put_tx('tx-alice-1', 'bbbbbbbb-0000-0000-0000-000000000002', 3000, now() + interval '2 minutes', null);
select test.check('cannot unshare a row',
  (select household_id = :'hid' and amount_minor = 3000 from public.transactions where id = 'tx-alice-1'));
-- A plain update that tries to unshare, or to take over a row, changes nothing.
update public.transactions set household_id = null, owner_id = 'bbbbbbbb-0000-0000-0000-000000000002',
  updated_at = now() + interval '3 minutes' where id = 'tx-alice-1';
select test.check('a plain update cannot unshare or take over a row',
  (select household_id = :'hid' and owner_id = 'aaaaaaaa-0000-0000-0000-000000000001' from public.transactions where id = 'tx-alice-1'));
-- A new row joins the household by itself.
select test.put_tx('tx-bob-2', 'bbbbbbbb-0000-0000-0000-000000000002', 10, now());
select test.check('a new row joins the household',
  (select household_id = :'hid' from public.transactions where id = 'tx-bob-2'));
reset role;

:as_alice
select test.rows('alice sees the new row', 'select 1 from public.transactions where id = ''tx-bob-2''', 1);
select test.fails('cannot put a row in someone else''s household',
  format($$select test.put_tx('tx-x', 'aaaaaaaa-0000-0000-0000-000000000001', 1, now(), %L::uuid)$$,
         '99999999-0000-0000-0000-000000000009'));
reset role;

------------------------------------------------------------------------
-- 5. Outsiders see nothing
------------------------------------------------------------------------
:as_carol
select test.rows('carol sees nothing', 'select 1 from public.transactions', 0);
select test.rows('carol sees no household', 'select 1 from public.households', 0);
select test.rows('carol sees no members', 'select 1 from public.household_members', 0);
select test.fails('carol cannot add rows to the household',
  format($$select test.put_tx('tx-c', 'cccccccc-0000-0000-0000-000000000003', 1, now(), %L::uuid)$$, :'hid'));
select test.rows('nobody reads invites', 'select 1 from public.household_invites', 0);
select test.fails('carol cannot remove members', format($$select public.remove_member(%L::uuid)$$, 'bbbbbbbb-0000-0000-0000-000000000002'));
reset role;

------------------------------------------------------------------------
-- 6. Internal functions are not reachable from the app
------------------------------------------------------------------------
:as_carol
select test.fails('_share_rows is internal', format($$select public._share_rows(%L::uuid, %L::uuid)$$, 'cccccccc-0000-0000-0000-000000000003', :'hid'));
select test.fails('_leave is internal', format($$select public._leave(%L::uuid)$$, 'bbbbbbbb-0000-0000-0000-000000000002'));
reset role;
set role anon;
select test.fails('anonymous cannot start a household', $$select public.create_household('x')$$);
reset role;

------------------------------------------------------------------------
-- 7. Owner removes a member
------------------------------------------------------------------------
:as_bob
select test.fails('a member cannot remove the owner', format($$select public.remove_member(%L::uuid)$$, 'aaaaaaaa-0000-0000-0000-000000000001'));
select test.fails('a member cannot rename', $$select public.rename_household('Mine')$$);
reset role;

:as_alice
select public.rename_household('Our home');
select test.check('renamed', (select name = 'Our home' from public.households));
select test.fails('cannot remove yourself', format($$select public.remove_member(%L::uuid)$$, 'aaaaaaaa-0000-0000-0000-000000000001'));
select public.remove_member('bbbbbbbb-0000-0000-0000-000000000002');
select test.rows('alice still sees all 3 rows', 'select 1 from public.transactions', 3);
reset role;

:as_bob
select test.rows('bob no longer sees the household rows', 'select 1 from public.transactions', 0);
select test.rows('bob no longer sees the household', 'select 1 from public.households', 0);
-- Bob starts personal rows again (the phone's copy).
select test.put_tx('tx-bob-copy', 'bbbbbbbb-0000-0000-0000-000000000002', 500, now());
select test.check('the copy stays personal', (select household_id is null from public.transactions where id = 'tx-bob-copy'));
select test.rows('bob sees only the copy', 'select 1 from public.transactions', 1);
reset role;

:as_alice
select test.rows('alice does not see bob''s personal copy', 'select 1 from public.transactions where id = ''tx-bob-copy''', 0);
reset role;

------------------------------------------------------------------------
-- 7b. The household plan wins
------------------------------------------------------------------------
-- Alice has a plan for the household.
:as_alice
insert into public.plans (id, owner_id, template, income_minor, currency, active_from, updated_at)
values ('plan-alice', 'aaaaaaaa-0000-0000-0000-000000000001', 'balanced', 200000, 'USD', '2026-10-01', now());
select test.check('alice plan is in the household', (select household_id is not null from public.plans where id = 'plan-alice'));
select public.create_invite() as code2 \gset
reset role;

-- Dave has his own plan and joins.
:as_dave
insert into public.plans (id, owner_id, template, income_minor, currency, active_from, updated_at)
values ('plan-dave', 'dddddddd-0000-0000-0000-000000000004', 'balanced', 100000, 'USD', '2026-10-01', now());
select public.join_household(:'code2', 'Dave');
select test.check('dave''s plan moved to his library',
  (select active_from is null and household_id = :'hid' from public.plans where id = 'plan-dave'));
select test.check('alice''s plan is untouched',
  (select active_from = '2026-10-01' from public.plans where id = 'plan-alice'));
reset role;

------------------------------------------------------------------------
-- 8. Leaving, ownership and dissolving
------------------------------------------------------------------------
:as_alice
select test.check('the owner leaves, the household goes on',
  (select public.leave_household() = 'left'));
select test.rows('alice sees nothing of the household any more', 'select 1 from public.transactions', 0);
reset role;

:as_dave
select test.check('dave is the owner now',
  (select owner_id = 'dddddddd-0000-0000-0000-000000000004' from public.households));
select test.check('dave still sees what the household has', (select count(*) = 3 from public.transactions));
select test.check('dave can invite now', (select length(public.create_invite()) = 8));
select test.check('the last member leaving dissolves it',
  (select public.leave_household() = 'dissolved'));
select test.check('everything is dave''s own now',
  (select count(*) = 3 and bool_and(household_id is null and owner_id = 'dddddddd-0000-0000-0000-000000000004') from public.transactions));
reset role;
select test.check('the household is gone', (select count(*) = 0 from public.households));

------------------------------------------------------------------------
-- 9. Deleting an account keeps the household's data
------------------------------------------------------------------------
:as_carol
select public.create_household('Carol house', 'Carol') as chid \gset
select public.create_invite() as ccode \gset
reset role;

:as_eve
select public.join_household(:'ccode', 'Eve');
select test.put_tx('tx-eve-1', 'eeeeeeee-0000-0000-0000-000000000005', 42, now());
select public.delete_my_account();
reset role;

select test.check('eve is gone', (select count(*) = 0 from auth.users where id = 'eeeeeeee-0000-0000-0000-000000000005'));
select test.check('her entry stays with the household, now carol''s',
  (select household_id = :'chid' and owner_id = 'cccccccc-0000-0000-0000-000000000003' from public.transactions where id = 'tx-eve-1'));
select test.check('carol is the only member', (select count(*) = 1 from public.household_members where household_id = :'chid'));

-- A user outside any household can still delete their account.
:as_bob
select public.delete_my_account();
reset role;
select test.check('bob''s personal rows are gone', (select count(*) = 0 from public.transactions where owner_id = 'bbbbbbbb-0000-0000-0000-000000000002'));

\echo household checks passed
