#!/bin/bash
set -e

   psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
EOSQL

   psql -d fts_with_pg -c "CREATE EXTENSION IF NOT EXISTS pg_trgm"
   psql -d fts_with_pg -c "CREATE EXTENSION IF NOT EXISTS unaccent;"
