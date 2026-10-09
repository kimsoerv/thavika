# Thavika

A simple money app for everyday people: note daily spending and income, plan the
month, track plan against what really happened, and save toward goals. Works fully
offline; sign-in and sync (Supabase, free plan) and Gemini scanning with your own key
are planned. English and Khmer.

Status: the offline app (Phase A) is built. See [docs/roadmap.md](docs/roadmap.md)
for what is done and what is next.

## What it does

- Quick entry (keypad, typed line such as `coffee 2.5`, voice), wallets, tags,
  receipt photos, split entries
- Plans: 50/30/20, 70/20/10, 80/20 or your own; plan check with "safe to spend today"
- Reminders, bills and subscriptions, savings goals and challenges, debts, net worth
- Reports with charts, CSV and Excel export, backup and restore
- PIN and fingerprint lock, English and Khmer, Android home-screen widget

## Stack

Flutter, GetX (state, routing, dependency injection), Drift (SQLite), Dio and
Supabase (planned for sync). Money is stored as whole minor units (cents).

## Run

```bash
flutter pub get
flutter run
```

Tests and checks:

```bash
flutter analyze
flutter test
```

## Translations

`lib/l10n/app_en.arb` is the template. Khmer is generated from `tool/km_strings.py`:

```bash
python3 tool/sync_arb.py && flutter gen-l10n
```

The Khmer text is a draft and needs review by a native speaker.

## Docs

- [docs/feature-spec.md](docs/feature-spec.md) what the app should do
- [docs/technical-design.md](docs/technical-design.md) how it is built
- [docs/roadmap.md](docs/roadmap.md) build order and progress

Local settings (Supabase URL and keys) go in `env.json`, which is not committed;
see `env.example.json`.
