#!/usr/bin/env python3
"""FATEEN schema migration runner and ledger auditor.

Usage (from the backend root):
    python scripts/migrate.py status  [--database-url URL]
    python scripts/migrate.py apply   [--database-url URL] [--to VERSION] [--dry-run]

The database URL defaults to MIGRATION_DATABASE_URL, then DATABASE_URL. Use a
role that owns the schema (not the fateen_app runtime role).

Ledger contract (compatible with the legacy migrate.ps1 and the Cloud ledger):
    public.schema_migrations(version text PK, checksum text, applied_at timestamptz)
    version  = migration file name, e.g. "0053_restore_fateen_app_history_write_path.sql"
    checksum = lowercase hex MD5 of the file's bytes

Rules this tool enforces:
  * A ledger row is written only in the same request that executed the file,
    after the file ran without error. There is no command that records a
    migration without running it.
  * An applied migration whose file bytes changed is a hard error: migrations
    are immutable, ship a new one instead.
  * `apply` refuses to run while the ledger holds versions that are not in
    this repository (for example migrations applied from another checkout).
    Import those files first, so the repository stays the single source of
    truth for the schema.
  * 0000_recovered_baseline.sql is a pg_dump of the schema produced by the
    legacy chain 0001-0039 plus 002_collector_tables. A database whose ledger
    already carries that whole chain is treated as having the baseline; the
    baseline is never re-run there and no row is invented for it.

Atomicity: each file is sent as one simple-query request with the ledger
INSERT appended. Without explicit BEGIN/COMMIT the whole request is one
implicit transaction. Files that carry their own BEGIN/COMMIT commit their
body themselves; the ledger row follows only if every statement succeeded.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import re
import sys
from dataclasses import dataclass
from pathlib import Path

import psycopg
from psycopg import sql as pgsql
from psycopg.rows import dict_row

BACKEND_ROOT = Path(__file__).resolve().parent.parent
MIGRATIONS_DIR = BACKEND_ROOT / "migrations"
LEGACY_DIR = BACKEND_ROOT / "legacy_archive" / "migrations"

BASELINE = "0000_recovered_baseline.sql"
# Ledger versions that together produced the schema captured in BASELINE.
LEGACY_CHAIN_EXTRA = ("002_collector_tables",)

_FILE_RE = re.compile(r"^(\d+)_[A-Za-z0-9_]+\.sql$")
# psql-only meta-commands emitted by pg_dump >= 17.6; not SQL.
_PSQL_META_RE = re.compile(r"^\\(un)?restrict\b.*$", re.MULTILINE)
# Session setting that only exists on PostgreSQL >= 17.
_PG17_ONLY_RE = re.compile(r"^SET transaction_timeout = 0;$", re.MULTILINE)

_SELF_REGISTER_RE = re.compile(r"INSERT\s+INTO\s+public\.schema_migrations", re.IGNORECASE)
_MD5_RE = re.compile(r"^[0-9a-f]{32}$")

LEDGER_DDL = """
CREATE TABLE IF NOT EXISTS public.schema_migrations (
    version text PRIMARY KEY,
    checksum text NOT NULL,
    applied_at timestamptz NOT NULL DEFAULT now()
)
"""


@dataclass(frozen=True)
class Migration:
    version: str
    path: Path
    order: int

    @property
    def checksum(self) -> str:
        return hashlib.md5(self.path.read_bytes()).hexdigest()

    @property
    def stem(self) -> str:
        return self.version[: -len(".sql")]

    @property
    def self_registers(self) -> bool:
        """0042/0043 insert their own ledger row (version = stem, checksum =
        a label). The runner must not add a second row for them."""
        return bool(_SELF_REGISTER_RE.search(self.path.read_text(encoding="utf-8")))


def discover(directory: Path = MIGRATIONS_DIR) -> list[Migration]:
    found = []
    for path in directory.glob("*.sql"):
        match = _FILE_RE.match(path.name)
        if not match:
            raise SystemExit(f"Unexpected file name in {directory}: {path.name}")
        found.append(Migration(path.name, path, int(match.group(1))))
    found.sort(key=lambda m: (m.order, m.version))
    orders = [m.order for m in found]
    duplicates = sorted({o for o in orders if orders.count(o) > 1})
    if duplicates:
        raise SystemExit(f"Duplicate migration numbers: {duplicates}")
    return found


def legacy_chain() -> set[str]:
    chain = {p.name for p in LEGACY_DIR.glob("00[0-3][0-9]_*.sql")}
    return chain | set(LEGACY_CHAIN_EXTRA)


def database_url(cli_value: str | None) -> str:
    url = cli_value or os.environ.get("MIGRATION_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("No database URL: pass --database-url or set MIGRATION_DATABASE_URL")
    return url


def read_ledger(conn) -> dict[str, str] | None:
    exists = conn.execute("SELECT to_regclass('public.schema_migrations') IS NOT NULL AS e").fetchone()["e"]
    if not exists:
        return None
    rows = conn.execute("SELECT version, checksum FROM public.schema_migrations").fetchall()
    return {r["version"]: r["checksum"].lower() for r in rows}


@dataclass
class Plan:
    applied: list[Migration]
    unverified: list[Migration]
    pending: list[Migration]
    mismatched: list[Migration]
    unknown: list[str]
    baseline_via_legacy: bool
    legacy_missing: list[str]


def plan(migrations: list[Migration], ledger: dict[str, str]) -> Plan:
    chain = legacy_chain()
    chain_present = chain & ledger.keys()
    baseline_via_legacy = BASELINE not in ledger and chain_present == chain
    applied, unverified, pending, mismatched = [], [], [], []
    for m in migrations:
        if m.version in ledger:
            (applied if ledger[m.version] == m.checksum else mismatched).append(m)
        elif m.stem in ledger:
            # Recorded under its stem. An MD5 there can still be verified;
            # a label such as 'fateen-pilot-0042-v1' cannot.
            recorded = ledger[m.stem]
            if not _MD5_RE.match(recorded):
                unverified.append(m)
            else:
                (applied if recorded == m.checksum else mismatched).append(m)
        elif m.version == BASELINE and baseline_via_legacy:
            applied.append(m)
        else:
            pending.append(m)
    known = {m.version for m in migrations} | {m.stem for m in migrations} | chain
    unknown = sorted(v for v in ledger if v not in known)
    legacy_missing = sorted(chain - ledger.keys()) if chain_present else []
    return Plan(applied, unverified, pending, mismatched, unknown, baseline_via_legacy, legacy_missing)


def print_status(migrations: list[Migration], ledger: dict[str, str] | None) -> int:
    if ledger is None:
        print("Ledger: public.schema_migrations does not exist (empty database).")
        for m in migrations:
            print(f"  PENDING   {m.version}")
        return 0
    p = plan(migrations, ledger)
    print(f"Ledger rows: {len(ledger)}   repository migrations: {len(migrations)}")
    if p.baseline_via_legacy:
        print(f"  (baseline {BASELINE} satisfied by the legacy chain 0001-0039 + 002 in the ledger)")
    for m in migrations:
        if m in p.applied:
            print(f"  APPLIED   {m.version}")
        elif m in p.unverified:
            print(f"  APPLIED   {m.version}  (self-registered as {m.stem}; checksum is a label, not verifiable)")
        elif m in p.mismatched:
            print(f"  MODIFIED  {m.version}  (file checksum differs from ledger)")
        else:
            print(f"  PENDING   {m.version}")
    for v in p.unknown:
        print(f"  NOT IN REPO  {v}  (applied to this database, file missing from migrations/)")
    for v in p.legacy_missing:
        print(f"  LEGACY GAP   {v}  (partial legacy chain in ledger)")
    problems = bool(p.mismatched or p.unknown or p.legacy_missing)
    print("Result:", "DRIFT - repository and database disagree" if problems else "consistent")
    return 1 if problems else 0


def _prepare_sql(text: str, server_version: int) -> str:
    text = _PSQL_META_RE.sub("", text)
    if server_version < 170000:
        text = _PG17_ONLY_RE.sub("", text)
    return text


def apply(url: str, target: str | None, dry_run: bool) -> int:
    migrations = discover()
    if target and target not in {m.version for m in migrations}:
        raise SystemExit(f"--to {target}: no such migration file")
    with psycopg.connect(url, autocommit=True, row_factory=dict_row) as conn:
        # The baseline dump creates the ledger table itself, so an empty
        # database gets it with the first migration (see LEDGER_DDL below).
        ledger = read_ledger(conn) or {}
        p = plan(migrations, ledger)
        if p.mismatched or p.unknown or p.legacy_missing:
            print_status(migrations, ledger)
            print("Refusing to apply: resolve the drift above first.", file=sys.stderr)
            return 1
        server_version = conn.info.server_version

    todo = []
    for m in p.pending:
        todo.append(m)
        if m.version == target:
            break
    if target and target not in {m.version for m in todo} | {m.version for m in p.applied}:
        raise SystemExit(f"--to {target}: not reachable")
    if not todo:
        print("Nothing to apply.")
        return 0

    for m in todo:
        if dry_run:
            print(f"  WOULD APPLY  {m.version}")
            continue
        sql = _prepare_sql(m.path.read_text(encoding="utf-8"), server_version)
        if not m.self_registers:
            sql += (
                "\n;\n"
                + LEDGER_DDL
                + ";\nINSERT INTO public.schema_migrations (version, checksum) VALUES ("
                + pgsql.quote(m.version)
                + ", "
                + pgsql.quote(m.checksum)
                + ");"
            )
        # A fresh connection per file: dumps change session settings
        # (search_path = '') that must not leak into the next migration.
        with psycopg.connect(url, autocommit=True) as conn:
            conn.execute(sql)
        print(f"  APPLIED  {m.version}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("status", "apply"):
        sp = sub.add_parser(name)
        sp.add_argument("--database-url")
        if name == "apply":
            sp.add_argument("--to", dest="target", help="stop after this migration file name")
            sp.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    url = database_url(args.database_url)

    if args.command == "status":
        with psycopg.connect(url, autocommit=True, row_factory=dict_row) as conn:
            return print_status(discover(), read_ledger(conn))
    return apply(url, args.target, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
