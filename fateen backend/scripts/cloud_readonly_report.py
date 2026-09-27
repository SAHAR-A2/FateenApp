#!/usr/bin/env python3
"""Run every read-only Cloud check in one go and save the results to a folder.

Usage (from the backend root):
    python scripts/cloud_readonly_report.py [--database-url URL] [--out DIR]

The URL defaults to CLOUD_DATABASE_URL, then DATABASE_URL.

Runs, in order, the checks from docs/MIGRATIONS_GOVERNANCE.md:
    migrate.py status          -> status.txt
    db_audit.py (text + JSON)  -> audit.txt, audit.json
    export_reference_seed.py   -> reference_data.sql
plus meta.txt: when, which commit, which server and role, and each exit code.

Nothing can be written to the database: every connection the three tools
open is switched to default_transaction_read_only before its first query,
and the switch is verified. PostgreSQL itself then rejects any write, even
one a tool issued by mistake.
"""

from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import os
import subprocess
import sys
import traceback
from datetime import datetime, timezone
from pathlib import Path

import psycopg
from psycopg.rows import tuple_row

HERE = Path(__file__).resolve().parent
BACKEND_ROOT = HERE.parent
sys.path.insert(0, str(BACKEND_ROOT))

_real_connect = psycopg.connect


def _read_only_connect(*args, **kwargs):
    conn = _real_connect(*args, **kwargs)
    autocommit = conn.autocommit
    conn.autocommit = True
    cur = conn.cursor(row_factory=tuple_row)
    cur.execute("SET default_transaction_read_only = on")
    if cur.execute("SHOW default_transaction_read_only").fetchone()[0] != "on":
        conn.close()
        raise SystemExit("Could not make the connection read-only; stopping.")
    conn.autocommit = autocommit
    return conn


def _load(name: str):
    spec = importlib.util.spec_from_file_location(name, HERE / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


def _run(label: str, func, argv: list[str], out_file: Path | None) -> str:
    """Call a tool's main(), capturing its output. Returns a one-line outcome."""
    buf = io.StringIO()
    try:
        with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(buf):
            code = func(argv)
        outcome = f"exit {code}"
    except SystemExit as exc:
        outcome = f"exit {exc.code}"
    except Exception:
        buf.write(traceback.format_exc())
        outcome = "ERROR (see file)"
    if out_file is not None:
        out_file.write_text(buf.getvalue(), encoding="utf-8")
    print(f"  {label}: {outcome}")
    return outcome


def _git(*args: str) -> str:
    try:
        return subprocess.run(
            ["git", *args], cwd=BACKEND_ROOT, capture_output=True, text=True, check=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return "unknown"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--database-url")
    parser.add_argument("--out", help="output folder (default: cloud_report_<UTC time>)")
    args = parser.parse_args(argv)

    url = args.database_url or os.environ.get("CLOUD_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("No database URL: pass --database-url or set CLOUD_DATABASE_URL")
    started = datetime.now(timezone.utc)
    out = Path(args.out or f"cloud_report_{started.strftime('%Y%m%dT%H%M%SZ')}")
    out.mkdir(parents=True, exist_ok=True)

    psycopg.connect = _read_only_connect
    with psycopg.connect(url, connect_timeout=30) as conn:
        user, db, version = conn.execute(
            "SELECT current_user, current_database(), version()"
        ).fetchone()
        conn.rollback()
    print(f"Connected read-only as {user} to {db}. Writing results to {out}/")

    migrate, db_audit, seed = _load("migrate"), _load("db_audit"), _load("export_reference_seed")
    outcomes = {
        "migrate.py status": _run(
            "migrate.py status", migrate.main, ["status", "--database-url", url], out / "status.txt"
        ),
        "db_audit.py": _run(
            "db_audit.py", db_audit.main, ["--database-url", url, "--samples", "20"], out / "audit.txt"
        ),
        "db_audit.py --json": _run(
            "db_audit.py --json", db_audit.main, ["--database-url", url, "--json"], out / "audit.json"
        ),
        "export_reference_seed.py": _run(
            "export_reference_seed.py",
            seed.main,
            ["--database-url", url, "--out", str(out / "reference_data.sql")],
            None,
        ),
    }

    dirty = "yes" if _git("status", "--porcelain", "--", ".") else "no"
    meta = [
        f"started_utc: {started.strftime('%Y-%m-%dT%H:%M:%SZ')}",
        f"git_branch: {_git('rev-parse', '--abbrev-ref', 'HEAD')}",
        f"git_commit: {_git('rev-parse', 'HEAD')}",
        f"git_uncommitted_changes: {dirty}",
        f"db_user: {user}",
        f"db_name: {db}",
        f"server: {version}",
        "connections: default_transaction_read_only = on (verified)",
        "",
        *(f"{name}: {result}" for name, result in outcomes.items()),
        "",
        "migrate.py status exits 1 on DRIFT (e.g. NOT IN REPO rows); that is a finding, not a failure.",
    ]
    (out / "meta.txt").write_text("\n".join(meta) + "\n", encoding="utf-8")
    print(f"Done. Send the whole {out}/ folder back.")
    return 1 if any(r.startswith("ERROR") for r in outcomes.values()) else 0


if __name__ == "__main__":
    sys.exit(main())
