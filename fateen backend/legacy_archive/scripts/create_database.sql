-- =============================================================================
-- create_database.sql - create the Fateen database and its owner role
-- -----------------------------------------------------------------------------
-- Purpose:       Idempotently create the application database and the role that
--                owns it. Passwords are provisioned out-of-band (see Rationale).
-- Usage:         psql -v db_name=fateen -v db_owner=fateen_app \
--                    [-v db_owner_password='...'] -f scripts/create_database.sql postgres
-- Dependencies:  None. Run against the maintenance database (usually "postgres").
-- Migration:     Bootstrap only; not part of the numbered migration sequence.
-- Rationale:     CREATE DATABASE cannot run inside a transaction or DO block,
--                so it is issued via psql \gexec guarded by an existence check.
--                db_owner_password is OPTIONAL: when supplied the role is created
--                with LOGIN + PASSWORD; otherwise LOGIN only (external auth such
--                as PGPASSWORD, a broker, or an on-prem secret vault).
-- =============================================================================
\set ON_ERROR_STOP on

-- -----------------------------------------------------------------------------
-- Create the owner role if it does not exist.
-- -----------------------------------------------------------------------------
\if :{?db_owner_password}
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_owner') THEN
            EXECUTE format('CREATE ROLE %I LOGIN PASSWORD %L', :'db_owner', :'db_owner_password');
        END IF;
    END
    $$;
\else
    DO $$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_owner') THEN
            EXECUTE format('CREATE ROLE %I LOGIN', :'db_owner');
        END IF;
    END
    $$;
\endif

-- -----------------------------------------------------------------------------
-- Create the database if it does not exist.
-- -----------------------------------------------------------------------------
SELECT 'CREATE DATABASE ' || quote_ident(:'db_name') || ' OWNER ' || quote_ident(:'db_owner')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = :'db_name')
\gexec

-- -----------------------------------------------------------------------------
-- Grant schema usage on the default public schema to the owner (new clusters
-- restrict it to the bootstrap superuser; this is a no-op when already granted).
-- -----------------------------------------------------------------------------
\connect :db_name
GRANT ALL ON SCHEMA public TO :db_owner;

-- -----------------------------------------------------------------------------
-- Apply migrations next:
--   psql -v ON_ERROR_STOP=1 --single-transaction -f migrations/0001_foundation_extensions.sql :db_name
-- or use:  powershell -File scripts/migrate.ps1 -Database :db_name
-- -----------------------------------------------------------------------------
