"""Fateen Data Agent CLI.

Commands:
  setup            create the agent schema in the dev database
  run              process a batch of products (CSV/JSON/TXT of barcodes)
                   --offline: synthetic fixtures only, no network, no DB writes
  health           report database / web / sources / mode / configuration
  barcode          validate/normalize a barcode
  review           list the review queue
  candidates       list processed candidates
"""

from __future__ import annotations

import argparse
import csv
import json
import logging
import os
import sys
from pathlib import Path
from typing import Optional

from .config import Settings, get_settings
from .db.repository import FateenRepository
from .db.setup import ensure_agent_schema
from .pipeline.batch import BatchProcessor
from .pipeline.orchestrator import Orchestrator
from .reporting import render_detail_table, render_summary, summarize
from .sources import default_sources, enabled_sources
from .sources.base import ProductQuery

LOG_FORMAT = "%(asctime)s %(levelname)s %(name)s: %(message)s"


def _setup_logging(verbose: bool) -> None:
    logging.basicConfig(level=logging.DEBUG if verbose else logging.INFO, format=LOG_FORMAT)


def _load_products(path: str) -> list[tuple[ProductQuery, str, str]]:
    """Load product queries from CSV/JSON/TXT."""
    ext = os.path.splitext(path)[1].lower()
    queries: list[tuple[ProductQuery, str, str]] = []
    if ext == ".csv":
        with open(path, newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                q = ProductQuery(
                    barcode=row.get("barcode") or None,
                    name=row.get("name") or None,
                    brand=row.get("brand") or None,
                    company=row.get("company") or None,
                )
                key = row.get("barcode") or row.get("name")
                if key:
                    queries.append((q, key, "barcode" if row.get("barcode") else "name"))
    elif ext == ".json":
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)
        for item in data:
            q = ProductQuery(**{k: item.get(k) for k in ("barcode", "name", "brand", "company")})
            key = item.get("barcode") or item.get("name")
            if key:
                queries.append((q, key, "barcode" if item.get("barcode") else "name"))
    else:  # .txt — one barcode per line
        with open(path, encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if line:
                    queries.append((ProductQuery(barcode=line), line, "barcode"))
    if not queries:
        print("No products found in input file.", file=sys.stderr)
        sys.exit(1)
    return queries


def cmd_setup(settings: Settings, args) -> int:
    ensure_agent_schema(settings)
    print(f"agent schema ready in database '{settings.db_name}'")
    return 0


def cmd_run(settings: Settings, args) -> int:
    if args.offline:
        return _run_offline(settings, args)

    queries = _load_products(args.input)
    repo = FateenRepository(settings)
    sources = enabled_sources(default_sources(settings))
    if args.verbose:
        for s in sources:
            print(f"source enabled: {s.name} ({s.description})")

    batch_id = repo.start_batch(args.label)
    orchestrator = Orchestrator(
        repository=repo,
        sources=sources,
        batch_id=batch_id,
        promote_verified=False,  # never promote in CLI MVP; opt-in via code
    )

    processor = BatchProcessor(
        process_one=orchestrator.process,
        batch_label=args.label,
        batch_id=batch_id,
        workers=args.workers,
        retries=args.retries,
        rate_limit_per_sec=args.rate,
        skip_processed=settings.skip_processed,
        processed_check=repo.is_processed if settings.skip_processed else None,
        record_batch_item=repo.record_batch_item,
    )

    result = processor.run(queries)
    summary = result.summary
    summary.finished_at = None
    repo.finish_batch(batch_id, summary)

    print("\n" + render_summary(summary))
    if args.table:
        render_detail_table(result.outcomes)

    if args.output:
        os.makedirs(args.output, exist_ok=True)
        out = os.path.join(args.output, f"report_{args.label}.json")
        with open(out, "w", encoding="utf-8") as fh:
            json.dump(summary.model_dump(), fh, ensure_ascii=False, indent=2, default=str)
        print(f"\nreport written to {out}")
    return 0


_SYNTHETIC_BANNER = """\
===================================================================
 SYNTHETIC OFFLINE RUN  (FATEEN_LIVE_WEB=false, FATEEN_AGENT_DRY_RUN=true)
 The following products come from clearly-marked synthetic fixtures.
 They are NOT real verified product facts and MUST NOT be treated
 as production data. This run only exercises the agent pipeline.
===================================================================
"""


def _run_offline(settings: Settings, args) -> int:
    from .db.inmemory import InMemoryRepository, default_vocabulary_path, load_vocabulary
    from .health import collect as collect_health
    from .sources.fixture import FixtureSource

    fixture_path = args.fixture or settings.fixture_path or None
    fixture = FixtureSource(fixture_path)
    if not fixture.health():
        print(f"Fixture not found or empty: {fixture.path}", file=sys.stderr)
        return 1

    vocab_path = args.vocab or None
    seed = load_vocabulary(vocab_path or default_vocabulary_path())
    seed_path = Path(vocab_path) if vocab_path else default_vocabulary_path()

    if args.all_fixtures:
        queries = []
        for entry in fixture._entries:
            q = entry.get("query") or {}
            pq = ProductQuery(
                barcode=q.get("barcode"),
                name=q.get("name"),
                brand=q.get("brand"),
                company=q.get("company"),
            )
            key = q.get("barcode") or q.get("name")
            if key:
                queries.append((pq, key, "barcode" if q.get("barcode") else "name"))
    else:
        queries = _load_products(args.input)

    print(_SYNTHETIC_BANNER)
    print(f"fixture: {fixture.path} ({len(fixture._entries)} cases)\n")

    repo = InMemoryRepository(seed=seed)
    n_ingredients = len(seed.get("canonical_ingredients", {}))
    n_aliases = len(seed.get("aliases", []))
    n_allergens = len(seed.get("ingredient_allergens", []))
    n_flags = len(seed.get("ingredient_health_flags", []))
    print(
        f"vocabulary: {seed_path} "
        f"({n_ingredients} canonical ingredients, {n_aliases} aliases, "
        f"{n_allergens} ingredient->allergen links, {n_flags} ingredient->health-flag links)"
    )
    if not seed.get("canonical_ingredients"):
        print("warning: no vocabulary loaded — canonicalization will be a no-op", file=sys.stderr)

    batch_id = repo.start_batch(args.label)
    orchestrator = Orchestrator(
        repository=repo,
        sources=[fixture],
        batch_id=batch_id,
        promote_verified=False,
    )
    processor = BatchProcessor(
        process_one=orchestrator.process,
        batch_label=args.label,
        batch_id=batch_id,
        workers=1,
        retries=args.retries,
        rate_limit_per_sec=args.rate,
        skip_processed=False,
        record_batch_item=repo.record_batch_item,
    )

    result = processor.run(queries)
    summary = result.summary
    summary.finished_at = None
    repo.finish_batch(batch_id, summary)

    print("\n" + render_summary(summary))
    if args.table or args.verbose:
        print()
        render_detail_table(result.outcomes)

    report = {
        "meta": {
            "synthetic_fixtures": True,
            "warning": fixture.meta.get("note") or "Synthetic test fixtures — NOT production data.",
            "production_writes": 0,
        },
        "health": collect_health(settings.model_copy(update={"live_web": False})),
        "fixture": str(fixture.path),
        "summary": summary.model_dump(),
        "products": summary.details,
        "review_queue": [
            {
                "product_key": t.product_key,
                "problem": t.problem,
                "reason": t.reason,
                "missing_data": list(t.missing_data),
                "conflicting_sources": list(t.conflicting_sources),
                "suggested_action": t.suggested_action,
            }
            for t in repo.review_tasks
        ],
        "review_task_count": len(repo.review_tasks),
    }
    os.makedirs(args.output, exist_ok=True)
    out = os.path.join(args.output, f"offline_report_{args.label}.json")
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(report, fh, ensure_ascii=False, indent=2, default=str)
    print(f"\noffline report written to {out}")
    return 0


def cmd_health(settings: Settings, _args) -> int:
    from .health import collect

    data = collect(settings)

    def flag(ok: bool) -> str:
        return "OK " if ok else "FAIL"

    mode = data["mode"]
    print(f"Mode      : {mode['mode'].upper()}  (live_web={mode['live_web']}, dry_run={mode['dry_run']})")
    print(f"            {mode['label']}")
    print(f"Database  : {flag(data['database']['ok'])} {data['database']['detail']}")
    print(f"Web       : {flag(data['web']['ok'])} {data['web']['detail']}")
    print("Sources   :")
    for s in data["sources"]:
        print(f"            - {s['name']:22} {s['description']} [{'enabled' if s['available'] else 'disabled'}]")
    print("Config    :")
    for k, v in data["configuration"].items():
        print(f"            - {k}: {v}")
    return 0


def cmd_barcode(_settings: Settings, args) -> int:
    from .normalization.barcode import gtin_type, is_valid_gtin, normalize_barcode

    for raw in args.value:
        norm = normalize_barcode(raw)
        print(f"{raw!r} -> normalized={norm!r} valid_gtin={is_valid_gtin(norm)} type={gtin_type(norm)}")
    return 0


def cmd_review(settings: Settings, args) -> int:
    repo = FateenRepository(settings)
    conn = repo._get_conn()
    rows = conn.execute(
        """
        SELECT product_key, key_type, problem, status, reason, missing_data,
               conflicting_sources, suggested_action
        FROM agent.review_tasks
        WHERE (%(status)s IS NULL OR status = %(status)s)
        ORDER BY created_at DESC
        LIMIT %(limit)s
        """,
        {"status": args.status, "limit": args.limit},
    ).fetchall()
    if not rows:
        print("No review tasks.")
        return 0
    for r in rows:
        print("-" * 70)
        print(f"{r['product_key']} [{r['key_type']}] problem={r['problem']} state={r['status']}")
        print(f"  reason: {r['reason']}")
        if r["missing_data"]:
            print(f"  missing: {', '.join(r['missing_data'])}")
        if r["conflicting_sources"]:
            print(f"  conflicts: {r['conflicting_sources']}")
        print(f"  suggested: {r['suggested_action']}")
    return 0


def cmd_candidates(settings: Settings, args) -> int:
    repo = FateenRepository(settings)
    conn = repo._get_conn()
    rows = conn.execute(
        """
        SELECT product_key, key_type, name, brand, status, confidence, updated_at
        FROM agent.candidates
        ORDER BY updated_at DESC
        LIMIT %(limit)s
        """,
        {"limit": args.limit},
    ).fetchall()
    if not rows:
        print("No candidates.")
        return 0
    for r in rows:
        print(
            f"{r['product_key']:22} {r['status']:12} conf={r['confidence']:.2f} "
            f"name={r['name']!r} brand={r['brand']!r}"
        )
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="fateen-agent", description="Fateen Data Agent")
    p.add_argument("-v", "--verbose", action="store_true", help="debug logging")
    sub = p.add_subparsers(dest="command", required=True)

    s_setup = sub.add_parser("setup", help="create agent schema")
    s_setup.set_defaults(func=cmd_setup)

    s_run = sub.add_parser("run", help="process a batch of products")
    s_run.add_argument("input", nargs="?", help="CSV/JSON/TXT file of products")
    s_run.add_argument("--label", default="batch", help="batch label")
    s_run.add_argument("--workers", type=int, default=1)
    s_run.add_argument("--retries", type=int, default=1)
    s_run.add_argument("--rate", type=float, default=2.0, help="requests per second")
    s_run.add_argument("--table", action="store_true", help="render detail table")
    s_run.add_argument("--output", default="output", help="report output directory")
    s_run.add_argument(
        "--offline",
        action="store_true",
        help="offline mode: synthetic fixtures only, no network, no DB writes "
        "(FATEEN_LIVE_WEB=false, DRY_RUN=true)",
    )
    s_run.add_argument(
        "--fixture",
        default=None,
        help="path to the offline fixture JSON (default: tests/fixtures/products_10.json)",
    )
    s_run.add_argument(
        "--all-fixtures",
        action="store_true",
        help="run every query defined in the fixture (offline mode)",
    )
    s_run.add_argument(
        "--vocab",
        default=None,
        help="path to the offline vocabulary fixture (default: "
        "tests/fixtures/vocabulary.json)",
    )
    s_run.set_defaults(func=cmd_run)

    s_bc = sub.add_parser("barcode", help="validate barcodes")
    s_bc.add_argument("value", nargs="+")
    s_bc.set_defaults(func=cmd_barcode)

    s_rv = sub.add_parser("review", help="list review queue")
    s_rv.add_argument("--status", default=None, help="OPEN/IN_PROGRESS/RESOLVED")
    s_rv.add_argument("--limit", type=int, default=50)
    s_rv.set_defaults(func=cmd_review)

    s_c = sub.add_parser("candidates", help="list processed candidates")
    s_c.add_argument("--limit", type=int, default=50)
    s_c.set_defaults(func=cmd_candidates)

    s_h = sub.add_parser("health", help="report database/web/source/mode/configuration health")
    s_h.set_defaults(func=cmd_health)
    return p


def main(argv: Optional[list[str]] = None) -> int:
    args = build_parser().parse_args(argv)
    _setup_logging(args.verbose)
    settings = get_settings()
    return args.func(settings, args)


if __name__ == "__main__":
    sys.exit(main())
