# Thavika: technical implementation plan (Flutter)

Status: design only, nothing built yet. Companion to expense-app-feature-spec.md.
Machine check: Flutter 3.41.2 (stable), Dart 3.11.0 are installed. Package versions are checked when the project is created.

## 1. Architecture

Local-first. The Drift (SQLite) database on the phone is the single source of truth. The UI only reads from it (streams) and writes to it. Supabase is a replica that the sync engine keeps in step.

```
UI (screens, widgets)
   | observed by GetX controllers (Rx variables + Obx)
Repositories (TransactionRepo, PlanRepo, GoalRepo, ...)
   | read/write
Drift database  <------->  SyncEngine  <------->  Supabase (Postgres, Auth, Realtime)
   |
Domain logic (pure Dart): plan templates, pacing, safe to spend, recurring
```

Rules:

- A screen never calls Supabase directly.
- Every write goes through a repository and does two things in one database transaction: write the row, and add an outbox record.
- Domain logic is pure Dart functions with no Flutter or database imports, so it is easy to unit test.

## 2. Folder structure

```
lib/
  main.dart
  app.dart                  MaterialApp.router, theme, localization
  core/
    db/                     app_database.dart, tables/, daos/
    sync/                   sync_engine.dart, outbox.dart, pull.dart, push.dart
    supabase/               supabase_client.dart, auth_service.dart
    money/                  money.dart (minor units, formatting)
    notifications/          reminder_service.dart
    theme/, router/, utils/
  features/
    home/  entry/  transactions/  plan/  tracking/
    goals/  reports/  household/  settings/  scan/ (version 2)
  l10n/                     app_en.arb (add more languages later)
test/
supabase/
  migrations/               SQL files (tables, RLS, functions)
```

Each feature folder has `data/` (repository), `domain/` (models and pure logic), `presentation/` (screens, widgets, providers).

## 3. Packages

State, routing, dependency injection: get (GetX). Networking: dio (Supabase REST and Gemini REST). Deep links for invites: app_links. See section 10b.
Database: drift, drift_flutter (or sqlite3_flutter_libs), drift_dev and build_runner (dev).
Online: supabase_flutter, google_sign_in, connectivity_plus, workmanager.
Features: flutter_local_notifications, timezone, fl_chart, intl, uuid, local_auth, flutter_secure_storage, file_picker, share_plus, path_provider, excel, csv.
Version 2: image_picker, image (resize), http (Gemini REST).

## 4. Data model (Drift)

Rules for every synced table:

- `id` is a UUID created on the phone, so offline creation never clashes.
- Money is stored as integer minor units (cents) plus a currency code. Never use double for money.
- `updated_at` is set on every change (client time). `deleted_at` is a soft delete, so deletes sync as tombstones.
- `owner_id` is the signed-in user (null while guest). `household_id` is null unless shared.
- `sync_state` is `pending` or `synced`; the real queue is the outbox table.

Tables (version 1):

| Table | Main columns |
|---|---|
| categories | id, name, icon, kind (expense/income), group (needs/wants/savings/other), sort_order, is_default |
| transactions | id, type, amount_minor, currency, category_id, note, occurred_on, created_by |
| plans | id, template (50_30_20, 70_20_10, 80_20, custom), income_minor, currency, is_active |
| plan_items | id, plan_id, group_name, category_id or name, amount_minor, is_fixed |
| goals | id, name, target_minor, target_date, saved_minor |
| goal_contributions | id, goal_id, amount_minor, occurred_on |
| recurring_rules | id, type, amount_minor, category_id, note, frequency, next_run_on, is_active |
| households (local copy) | id, name, owner_id |
| household_members | household_id, user_id, display_name, role |
| outbox | id (auto), table_name, row_id, op (upsert/delete), created_at, attempts, last_error |
| sync_cursor | table_name, last_server_updated_at |
| app_settings | key, value (currency, language, reminder time, lock, last tab) |

Example table:

```dart
class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()(); // 'expense' | 'income'
  IntColumn get amountMinor => integer()();
  TextColumn get currency => text()();
  TextColumn get categoryId => text().references(Categories, #id)();
  TextColumn get note => text().withDefault(const Constant(''))();
  DateTimeColumn get occurredOn => dateTime()();
  TextColumn get createdBy => text().nullable()();
  TextColumn get ownerId => text().nullable()();
  TextColumn get householdId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();

  @override
  Set<Column> get primaryKey => {id};
}
```

Write pattern in a repository:

```dart
Future<void> addTransaction(TransactionDraft d) => db.transaction(() async {
  final row = d.toCompanion(id: uuid.v4(), updatedAt: clock.now());
  await db.into(db.transactions).insert(row);
  await db.outboxDao.enqueue('transactions', row.id.value, 'upsert');
  syncEngine.kick(); // non-blocking, does nothing if offline or guest
});
```

## 5. Sync engine

Push (local to Supabase), runs when: signed in, online, outbox not empty.

1. Read outbox rows in order, group by table (batches of about 100).
2. Load the current rows, then `upsert` them to Supabase (soft-deleted rows are upserted with `deleted_at`).
3. On success remove the outbox rows and set `sync_state = synced`.
4. On failure increase `attempts`, keep the row, retry with backoff (for example 5s, 30s, 5 min, capped). Network errors never lose data.

Pull (Supabase to local):

1. For each table, query rows where `server_updated_at > cursor`, ordered, in pages.
2. Apply each row to Drift: insert, or update only when the incoming `updated_at` is newer than the local one (last write wins). Skip rows that still have a pending outbox entry that is newer.
3. Save the new cursor. The cursor uses the server timestamp so phone clock differences do not break paging.

Triggers: app start, app resumed, connectivity regained, after a successful push, a Realtime event from Supabase (a household member changed something), and a periodic background task (workmanager; iPhone limits this, so foreground triggers matter most).

UI status: Saved on phone / Waiting to sync (outbox has rows) / Syncing / Synced, from a provider that watches the outbox count and engine state.

Last write wins is enforced on the server too with a trigger (section 6), so an old offline edit cannot overwrite a newer change.

Guest to signed-in: after sign-in, set `owner_id` on all local rows, enqueue every row, push. Idempotent because ids are UUIDs.

## 6. Supabase schema and security (sketch)

```sql
create table public.households (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);

create table public.household_members (
  household_id uuid references public.households(id) on delete cascade,
  user_id uuid references auth.users(id) on delete cascade,
  role text not null default 'member',
  display_name text,
  primary key (household_id, user_id)
);

create table public.household_invites (
  code text primary key,
  household_id uuid not null references public.households(id) on delete cascade,
  expires_at timestamptz not null
);

create table public.transactions (
  id uuid primary key,
  owner_id uuid not null references auth.users(id),
  household_id uuid references public.households(id),
  type text not null check (type in ('expense','income')),
  amount_minor bigint not null check (amount_minor >= 0),
  currency text not null,
  category_id uuid not null,
  note text not null default '',
  occurred_on date not null,
  created_by uuid references auth.users(id),
  updated_at timestamptz not null,
  deleted_at timestamptz,
  server_updated_at timestamptz not null default now()
);
-- same shape for categories, plans, plan_items, goals, goal_contributions, recurring_rules

create function public.is_household_member(hid uuid) returns boolean
language sql security definer set search_path = public as $$
  select exists (select 1 from household_members
                 where household_id = hid and user_id = auth.uid());
$$;

alter table public.transactions enable row level security;

create policy "read own or household" on public.transactions for select
  using (owner_id = auth.uid() or (household_id is not null and public.is_household_member(household_id)));
create policy "insert own" on public.transactions for insert
  with check (owner_id = auth.uid());
create policy "update own or household" on public.transactions for update
  using (owner_id = auth.uid() or (household_id is not null and public.is_household_member(household_id)));
-- no delete policy: deletes are soft (deleted_at)

-- server timestamp + last write wins
create function public.sync_guard() returns trigger language plpgsql as $$
begin
  if tg_op = 'UPDATE' and new.updated_at < old.updated_at then
    return old;            -- ignore stale edit
  end if;
  new.server_updated_at := now();
  return new;
end $$;
create trigger transactions_sync_guard before insert or update on public.transactions
  for each row execute function public.sync_guard();
```

Household actions run as database functions (RPC) with `security definer`, so the rules cannot be bypassed from the app:

- `create_household(name)`: creates the household and adds the owner as a member.
- `create_invite(household_id)`: owner only, makes a code that expires.
- `join_household(code)`: checks the code, adds the member, sets `household_id` on all of the caller's existing rows (share everything).
- `leave_household(household_id)`: removes the member; the rows stay with the household; creates copies of the leaver's entries and plan with `household_id = null` for the leaver.
- `remove_member(household_id, user_id)`: owner only, same copy behaviour.
- Owner leaves: ownership moves to the longest-standing member; last member leaves: household deleted.

Realtime is enabled on the synced tables so household members get updates quickly.

Account deletion: a function that deletes the user's personal rows and membership (required for store publishing).

## 7. Domain logic (pure Dart)

Plan templates: a table of percentages per template, turned into `plan_items` for an income. Round to whole units and give any rounding difference to the largest item so the total equals income.

Plan check (per category, month to date):

```dart
enum PaceStatus { onTrack, slightlyAhead, offTrack, over }

PaceStatus paceStatus({required int spent, required int budget, required DateTime today}) {
  if (budget <= 0) return spent > 0 ? PaceStatus.over : PaceStatus.onTrack;
  if (spent >= budget) return PaceStatus.over;
  final dim = DateUtils.getDaysInMonth(today.year, today.month);
  final expected = budget * today.day / dim;
  if (spent <= expected) return PaceStatus.onTrack;
  return spent / expected <= 1.15 ? PaceStatus.slightlyAhead : PaceStatus.offTrack;
}
```

Safe to spend today = (flexible budget total - flexible spent) / (days in month - day + 1), never below zero. Flexible means categories that are not fixed bills (rent) and not savings.

Projected savings = planned savings - max(0, projected month spending - flexible budget total), where projected spending = spent so far / day * days in month.

Recurring: on app start and in the background task, create entries for each active rule whose `next_run_on` is today or earlier, using a deterministic id (rule id + date), so running twice or on two phones never duplicates. Then advance `next_run_on`.

Reminders (local notifications):

- Daily "record today's spending" at the user's time (scheduled repeating).
- Over-pace and 80% / 100% warnings are checked after each save on this phone and after each pull, at most one per category per day and two per day overall.
- Limit to know: local notifications can only be raised when the app (or its background task) runs. If your wife adds a big expense, your phone learns about it at the next sync, which may be when you open the app. Instant alerts for a partner's spending would need push notifications (a Supabase Edge Function plus FCM), which I would leave out of version 1.

## 8. Auth

- Guest by default: no account, `owner_id` null.
- Google sign-in with `google_sign_in`, then `supabase.auth.signInWithIdToken` using the Google ID token. Requires an Android client (SHA-1) and an iOS client in Google Cloud, and the Google provider enabled in Supabase.
- Session persisted by supabase_flutter. Sign-out keeps local data on the phone (with a clear message), or offers to clear it.
- Invite links (`https://.../join?code=...` or a code typed in) are received with app_links and opened with GetX navigation to the join confirmation screen.

## 9. Gemini scan and import (version 2)

- Call the Gemini REST API from the phone with the user's key (secure storage). Request JSON output with a response schema so parsing does not break.
- Photo: resize to about 1500 px, send image plus the user's category list, today's date, and default currency.
- Excel/CSV: parse locally; send header plus 3 to 5 sample rows to find columns; map in code; send only descriptions in batches of about 50 for categories. Cache the column mapping per bank.
- Local categorization rules table (text pattern to category) checked before any AI call.
- Duplicate check on (date, amount, normalized description) before showing the review screen.
- The model name is one constant/setting.

## 10. Quality

- Unit tests for the pure logic: templates, rounding, pacing, safe to spend, recurring.
- Drift tests with an in-memory database for repositories and the outbox.
- Sync tests with a fake remote: offline then online, failure then retry, stale edit ignored, tombstone delete.
- A few widget tests for the quick add flow.
- No secrets in the repo. The Supabase anon key is allowed in the app because security is enforced by RLS; never ship the service role key. The Gemini key is only on the user's phone.

## 10b. GetX and Dio (decided by the user)

GetX:

- `GetMaterialApp` with `GetPage` routes and a Binding per feature. Controllers extend `GetxController`.
- Long-lived services are registered once at start with `Get.put(..., permanent: true)`: AppDatabase, ApiClient, AuthService, SyncService, ReminderService, SettingsService.
- Feature controllers are created lazily in bindings (`Get.lazyPut`) and disposed with their page.
- Drift streams are connected to Rx variables in `onInit` (`list.bindStream(repo.watchTransactions())`), so the UI is `Obx` over local data and never waits for the network.
- Controllers only call repositories and pure domain functions. No business rules, SQL, or HTTP inside controllers or widgets.
- Language switching uses `Get.updateLocale`; text still comes from `.arb` files with gen-l10n.
- Tests: controllers get their repositories through constructors/bindings, so tests can pass fakes.

Dio:

- Two clients. `supabaseDio` (base URL `https://<project>.supabase.co/rest/v1`) and `geminiDio` (Gemini API, version 2).
- supabase_flutter is kept only for Auth (Google sign-in, session, token refresh) and Realtime. All table reads and writes go through Dio.
- Interceptors on `supabaseDio`: add `apikey` (anon key) and `Authorization: Bearer <access token>` from the current session; on 401 refresh the session once and retry; map errors to app errors (offline, unauthorized, server, conflict); log in debug only. Timeouts: connect 10s, receive 30s.
- Requests used by sync:
  - Push: `POST /<table>?on_conflict=id` with header `Prefer: resolution=merge-duplicates,return=minimal` and a JSON array body (the server trigger ignores stale rows).
  - Pull: `GET /<table>?server_updated_at=gte.<cursor>&order=server_updated_at.asc&limit=500`. Use `gte`, not `gt`, and ignore rows already applied, because rows written in the same transaction share a timestamp and `gt` could skip some across pages.
  - Household actions: `POST /rpc/join_household`, `/rpc/leave_household`, `/rpc/create_invite`, `/rpc/remove_member`.
- Gemini calls use their own Dio with the user's key sent in a header (not in the URL) and a longer timeout.
- Retry for sync is handled by the sync engine's backoff, not by blind interceptor retries, so the outbox stays the single source of truth.
- Never log request bodies or keys in release builds.

## 11. Build milestones

1. Project setup, theme, localization, router, Drift schema, default categories.
2. Quick add, transactions list (edit, swipe delete, undo), Home with safe to spend.
3. Plans (templates, edit), budgets, plan check, reminders.
4. Goals, recurring, reports, backup/export and restore.
5. Supabase project, auth, sync engine, sync status, guest to signed-in upgrade.
6. Household (RPC functions, invite, join/leave confirmations, members screen, realtime).
7. Gemini scan and import (version 2).
8. Polish, PIN lock, empty states, store preparation.

## 12. Commands (when we start)

```bash
flutter create --org com.yourname --project-name thavika thavika
cd thavika
flutter pub add get dio app_links drift drift_flutter supabase_flutter google_sign_in \
  connectivity_plus workmanager flutter_local_notifications timezone fl_chart intl uuid \
  local_auth flutter_secure_storage file_picker share_plus path_provider excel csv
flutter pub add --dev drift_dev build_runner flutter_lints
dart run build_runner build
```
