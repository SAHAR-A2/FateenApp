-- =============================================================================
-- drop_database.sql — teardown helper for DEVELOPMENT ONLY
-- -----------------------------------------------------------------------------
-- Purpose:       Idempotently drop the Fateen database and owner role created by
--                create_database.sql.
-- Usage:         psql -v db_name=fateen -v db_owner=fateen_app \
--                    -f scripts/drop_database.sql postgres
-- Dependencies:  None. Run against the maintenance database.
-- Migration:     Bootstrap only; never run in production.
-- Warning:       DROP DATABASE fails if connections are open. Terminate them
--                first, e.g.:
--                  SELECT pg_terminate_backend(pid) FROM pg_stat_activity
--                  WHERE datname = 'fateen' AND pid <> pg_backend_pid();
-- =============================================================================
\set ON_ERROR_STOP on

SELECT 'DROP DATABASE ' || quote_ident(:'db_name')
WHERE EXISTS (SELECT FROM pg_database WHERE datname = :'db_name')
\gexec

SELECT 'DROP ROLE ' || quote_ident(:'db_owner')
WHERE EXISTS (SELECT FROM pg_roles WHERE rolname = :'db_owner')
\gexec
