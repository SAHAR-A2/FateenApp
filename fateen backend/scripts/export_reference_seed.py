#!/usr/bin/env python3
"""Export FateenDB reference data to a versioned, idempotent seed file.

Usage (from the backend root):
    python scripts/export_reference_seed.py --database-url URL [--out seed/reference_data.sql]

Read-only against the source (READ ONLY transaction). The output holds the
lookup and vocabulary tables that product data points at (statuses, units,
nutrition types, allergens, ingredient grammar, data sources, condition
rules), never products, users or history. To build a fresh database:

    python scripts/migrate.py apply --to 0000_recovered_baseline.sql
    psql "$URL" -v ON_ERROR_STOP=1 -f seed/reference_data.sql
    python scripts/migrate.py apply

(0042 onwards need the lifecycle statuses from the seed.) Loading it into a
database that already has these rows is a no-op.

Every row is inserted with its original id and ON CONFLICT DO NOTHING, so
re-running the seed, or running it on a database that already has these
rows, changes nothing. Tables are written parents first (foreign-key order);
the load runs with session_replication_role = replica only to allow
self-references inside one table, so it needs the schema owner role.
"""

from __future__ import annotations

import argparse
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from psycopg import sql
from psycopg.rows import dict_row

REFERENCE_TABLES = (
    "lifecycle_statuses",
    "languages",
    "countries",
    "regions",
    "source_types",
    "source_priorities",
    "evidence_types",
    "verification_statuses",
    "relationship_types",
    "barcode_types",
    "image_types",
    "package_types",
    "units",
    "unit_conversions",
    "measurement_bases",
    "nutrition_types",
    "allergen_types",
    "allergens",
    "health_flag_types",
    "health_flags",
    "product_categories",
    "ingredient_categories",
    "regulatory_authorities",
    "data_sources",
    "health_conditions",
    "condition_nutrition_rules",
    "ingredients",
    "ingredient_aliases",
    "ingredient_allergens",
)


def existing_tables(conn) -> list[str]:
    rows = conn.execute(
        """
        SELECT table_name FROM information_schema.tables
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
          AND table_name = ANY(%s)
        """,
        (list(REFERENCE_TABLES),),
    ).fetchall()
    return [r["table_name"] for r in rows]


def fk_order(conn, tables: list[str]) -> list[str]:
    """Parents before children, among the exported tables only."""
    edges = conn.execute(
        """
        SELECT child.relname AS child, parent.relname AS parent
        FROM pg_constraint c
        JOIN pg_class child ON child.oid = c.conrelid
        JOIN pg_class parent ON parent.oid = c.confrelid
        JOIN pg_namespace n ON n.oid = child.relnamespace AND n.nspname = 'public'
        WHERE c.contype = 'f'
          AND child.relname = ANY(%s) AND parent.relname = ANY(%s)
          AND child.relname <> parent.relname
        """,
        (tables, tables),
    ).fetchall()
    parents = {t: set() for t in tables}
    for e in edges:
        parents[e["child"]].add(e["parent"])
    ordered, done = [], set()
    # Stable: follow REFERENCE_TABLES order whenever dependencies allow.
    pending = [t for t in REFERENCE_TABLES if t in parents]
    while pending:
        ready = [t for t in pending if parents[t] <= done]
        if not ready:
            raise SystemExit(f"Foreign-key cycle between: {pending}")
        for t in ready:
            ordered.append(t)
            done.add(t)
        pending = [t for t in pending if t not in done]
    return ordered


def table_inserts(conn, table: str) -> tuple[int, list[str]]:
    columns = [
        r["column_name"]
        for r in conn.execute(
            """
            SELECT column_name FROM information_schema.columns
            WHERE table_schema = 'public' AND table_name = %s
              AND is_generated = 'NEVER'
            ORDER BY ordinal_position
            """,
            (table,),
        ).fetchall()
    ]
    col_sql = sql.SQL(", ").join(map(sql.Identifier, columns))
    order = sql.Identifier("id") if "id" in columns else sql.SQL("1")
    # Serialise with the server's own text form so every type round-trips.
    rows = conn.execute(
        sql.SQL("SELECT {} FROM public.{} ORDER BY {}").format(
            sql.SQL(", ").join(sql.SQL("{}::text").format(sql.Identifier(c)) for c in columns),
            sql.Identifier(table),
            order,
        )
    ).fetchall()
    lines = []
    for row in rows:
        values = sql.SQL(", ").join(
            sql.NULL if row[c] is None else sql.Literal(row[c]) for c in columns
        )
        lines.append(
            sql.SQL(
                "INSERT INTO public.{} ({}) OVERRIDING SYSTEM VALUE VALUES ({}) ON CONFLICT DO NOTHING;"
            )
            .format(sql.Identifier(table), col_sql, values)
            .as_string(conn)
        )
    return len(rows), lines


def export(url: str) -> str:
    with psycopg.connect(url, row_factory=dict_row) as conn:
        conn.execute("SET TRANSACTION READ ONLY")
        tables = fk_order(conn, existing_tables(conn))
        body, summary = [], []
        for table in tables:
            count, lines = table_inserts(conn, table)
            summary.append(f"--   {table}: {count}")
            body.append(f"\n-- {table} ({count} rows)")
            body.extend(lines)
        conn.rollback()

    header = [
        "-- FATEEN reference data seed (generated by scripts/export_reference_seed.py).",
        f"-- Exported: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}",
        "-- Load after migration 0000, before 0042. Idempotent (ON CONFLICT DO NOTHING).",
        "-- Row counts:",
        *summary,
        "",
        "BEGIN;",
        "SET LOCAL session_replication_role = replica;",
    ]
    footer = [
        "",
        "SELECT pg_catalog.setval('public.lifecycle_statuses_id_seq',",
        "    GREATEST((SELECT COALESCE(max(id), 1) FROM public.lifecycle_statuses), 1), true);",
        "COMMIT;",
        "",
    ]
    return "\n".join(header + body + footer)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--database-url")
    parser.add_argument("--out", default="seed/reference_data.sql")
    args = parser.parse_args(argv)
    url = args.database_url or os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("No database URL: pass --database-url or set DATABASE_URL")
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(export(url), encoding="utf-8")
    print(f"written: {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
