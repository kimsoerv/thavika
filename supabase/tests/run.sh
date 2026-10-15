#!/usr/bin/env bash
# Runs the migrations on a throw-away local Postgres and checks the rules.
#   supabase/tests/run.sh
# Needs a running Postgres and a superuser reachable with `psql -U postgres`
# (set PGHOST etc. as needed).
set -euo pipefail
cd "$(dirname "$0")"
DB=thavika_migration_test
PSQL="psql -X -q -v ON_ERROR_STOP=1 -U ${PGUSER:-postgres}"
$PSQL -d postgres -c "drop database if exists $DB" -c "create database $DB"
for f in stubs.sql ../migrations/0001_init.sql ../migrations/0002_households.sql households_test.sql; do
  echo "== $f"
  $PSQL -d $DB -f "$f" > /dev/null
done
$PSQL -d postgres -c "drop database $DB"
echo "all database checks passed"
