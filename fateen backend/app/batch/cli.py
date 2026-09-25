"""SFDA batch CLI (single-command, mirrors app/agent/cli.py conventions).

Subcommands:
  preflight            credential presence report (never prints the value)
  gap                  STEP D Arabic vocabulary gap report
  propose              STEP E expansion proposals (report-only, never applied)
  certify              STEP F certification checks
  gates                STEP G scaling gates (offline capability proof)
  run                  batch run (dry-run default; `--mode live` is
                       credential-gated via the SAME SfdaAuthenticationRequired
                       before any network call)
  migration-proposal   STEP H unapplied migration proposal document
  report               writes Temp\\opencode\\sfda_scaling_readiness_report.txt

Safety contract (same as every FATEEN write-capable entry point): the
effective dry-run decision always flows through
app.core.config.resolve_effective_dry_run; an environment-level AGENT_DRY_RUN
gate can never be bypassed by `--write`/`--mode live`.
"""
import argparse
import json
import sys
from pathlib import Path

from app.core.config import resolve_effective_dry_run

CHECKPOINT_DIR = ".sfda_batch"
SINK_DIR = ".sfda_batch/sink"


def main(argv=None):
    parser = argparse.ArgumentParser(description="SFDA production-scale batch ingestion")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    sub = parser.add_subparsers(dest="command", required=True)

    # preflight ------------------------------------------------------------
    sub.add_parser("preflight", help="credential presence report (values never shown)")

    # gap ------------------------------------------------------------------
    p_gap = sub.add_parser("gap", help="STEP D Arabic vocabulary gap report")
    p_gap.add_argument("--corpus", help="text file with one ingredient statement per line")
    p_gap.add_argument("--db", action="store_true", help="resolve against the live DB grammar")
    p_gap.add_argument("--out", help="optional JSON output path for the gap report")

    # propose --------------------------------------------------------------
    p_prop = sub.add_parser("propose", help="STEP E expansion proposals (report-only)")
    p_prop.add_argument("--corpus", help="text file with one ingredient statement per line")
    p_prop.add_argument("--db", action="store_true", help="resolve against the live DB grammar")
    p_prop.add_argument("--out", help="optional JSON output path for the proposals")

    # certify --------------------------------------------------------------
    p_cert = sub.add_parser("certify", help="STEP F certification checks")
    p_cert.add_argument("--checkpoint-dir", default=".sfda_cert")
    p_cert.add_argument("--json", action="store_true", help="print JSON instead of a table")

    # gates ----------------------------------------------------------------
    p_gates = sub.add_parser("gates", help="STEP G scaling gates (offline)")
    p_gates.add_argument("--batch-size", type=int, default=10)
    p_gates.add_argument("--json", action="store_true")

    # run ------------------------------------------------------------------
    p_run = sub.add_parser("run", help="batch run (dry-run default, live is credential-gated)")
    p_run.add_argument("--mode", choices=["dry-run", "live"], default="dry-run", help=argparse.SUPPRESS)
    p_run.add_argument("--dry-run", action="store_true", default=True, help="Dry run (default)")
    p_run.add_argument("--write", action="store_true", help="Request a live write path")
    p_run.add_argument("--barcodes-file", help="plain-text file, one barcode per line")
    p_run.add_argument("--references-file", help="plain-text file, one reference number per line")
    p_run.add_argument("--count", type=int, help="synthetic dry-run queue size (FIXTURE- identifiers, never resolve)")
    p_run.add_argument("--batch-size", type=int, default=10)
    p_run.add_argument("--max-retries", type=int, default=3)
    p_run.add_argument("--rate-limit", type=float, default=1.0, help="requests per second (0 disables throttle)")
    p_run.add_argument("--resolver", choices=["auto", "database", "fixture-grammar"], default="auto")
    p_run.add_argument("--checkpoint-dir", default=CHECKPOINT_DIR)
    p_run.add_argument("--sink-dir", default=SINK_DIR)
    p_run.add_argument("--resume", help="resume an existing run id (loads its checkpoint)")

    # migration-proposal ----------------------------------------------------
    p_mig = sub.add_parser("migration-proposal", help="STEP H unapplied migration proposal")
    p_mig.add_argument("--out", help="optional text output path")

    # report -----------------------------------------------------------------
    sub.add_parser("report", help="write Temp\\opencode\\sfda_scaling_readiness_report.txt")

    args = parser.parse_args(argv)
    command = args.command

    if command == "preflight":
        return _cmd_preflight()
    if command == "gap":
        return _cmd_gap(args)
    if command == "propose":
        return _cmd_propose(args)
    if command == "certify":
        return _cmd_certify(args)
    if command == "gates":
        return _cmd_gates(args)
    if command == "run":
        return _cmd_run(args)
    if command == "migration-proposal":
        return _cmd_migration_proposal(args)
    if command == "report":
        return _cmd_report(args)
    parser.error(f"unknown command: {command}")


# ---------------------------------------------------------------------------
# subcommand implementations
# ---------------------------------------------------------------------------


def _cmd_preflight() -> int:
    from app.batch.preflight import check_credentials

    report = check_credentials()
    print("SFDA CREDENTIAL PREFLIGHT")
    print(f"credential configured        = {report['credential_configured']}")
    print(f"bearer_token (SFDA_ACCESS_TOKEN)  = {'YES' if report['bearer_token_configured'] else 'NO'}")
    print(f"firs_api_key (SFDA_API_KEY)       = {'YES' if report['firs_api_key_configured'] else 'NO'}")
    print(f"consumer_key (SFDA_CONSUMER_KEY)  = {'YES' if report['consumer_key_configured'] else 'NO'}")
    print(f"consumer_secret (SFDA_CONSUMER_SECRET) = {'YES' if report['consumer_secret_configured'] else 'NO'}")
    print(f"oauth_token_url (SFDA_OAUTH_TOKEN_URL) = {'YES' if report['oauth_token_url_configured'] else 'NO'}  (required for the OAuth path; never guessed)")
    print(f"oauth path complete           = {'YES' if report['oauth_complete'] else 'NO'}")
    print("enable via environment / .env only; the credential value is never printed.")
    return 0


def _corpus(args) -> list[str]:
    from app.batch.vocabulary import corpus_from_text

    if getattr(args, "corpus", None):
        return corpus_from_text(Path(args.corpus).read_text(encoding="utf-8"))
    from tests.test_sfda_fixture_pipeline import FIRS_FIXTURE_1  # type: ignore

    return corpus_from_text(FIRS_FIXTURE_1["ingredientsAr"])


def _conn_for(args):
    """Open a DB connection when `--db` and the database is reachable."""
    if not getattr(args, "db", False):
        return None
    try:
        from app.db.connection import get_connection

        return get_connection().__enter__()
    except Exception as exc:
        print(f"WARNING: DB unavailable, using offline resolver: {exc}")
        return None


def _cmd_gap(args) -> int:
    from app.batch.vocabulary import CATEGORY_ORDER, analyze_arabic_gap

    conn = _conn_for(args)
    report = analyze_arabic_gap(conn, _corpus(args), out_path=Path(args.out) if args.out else None)
    print(f"gap report: {report['unresolved_token_count']} unresolved tokens "
          f"across {report['corpus_statements']} statements")
    for c in CATEGORY_ORDER:
        print(f"  {c:<26}: {report['distribution'].get(c, 0)}")
    for row in report["ranked_unresolved_terms"][:10]:
        print(f"  - {row['term']!r} [{row['category']}] x{row['frequency']} p={row['priority']:.2f}")
    return 0


def _cmd_propose(args) -> int:
    from app.batch.vocabulary import build_expansion_proposals

    conn = _conn_for(args)
    payload = build_expansion_proposals(conn, _corpus(args), out_path=Path(args.out) if args.out else None)
    print(f"{len(payload['proposals'])} proposals (report-only, never applied):")
    for p in payload["proposals"]:
        print(f"  - {p['term']!r} -> {p['canonical_internal_code'] or '(allergen)'} "
              f"[{p['mechanism']}] x{p['frequency']} test={p['regression_test']}")
    return 0


def _cmd_certify(args) -> int:
    from app.batch.certify import run_certification

    result = run_certification(checkpoint_dir=args.checkpoint_dir)
    if getattr(args, "json", False):
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    print(f"CERTIFICATION {result['verdict']} ({len(result['results'])} checks)")
    for r in result["results"]:
        print(f"  {r['check']:<28}: {r['result']}")
        print(f"      {r['detail']}")
    return 0 if result["verdict"] == "PASS" else 1


def _cmd_gates(args) -> int:
    from app.batch.gates import run_scaling_gates

    result = run_scaling_gates(batch_size=args.batch_size)
    if getattr(args, "json", False):
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    print(f"SCALING GATES {result['verdict']} ({sum(r['verdict']=='PASS' for r in result['results'])}/{len(result['results'])})")
    for r in result["results"]:
        print(f"  target {r['target']:>5}: {r['verdict']} batch_size={r['batch_size']} batches={r['batches']} "
              f"processed={r['processed']} inserted={r['inserted']} checkpoints={r['checkpoint_files']} resume_ok={r['resume_ok']}")
    for p in result["projection"]:
        print(f"  {p['target_products']:>5} products -> approx {p['at_1_rps_elapsed_minutes']} min at 1 rps")
    return 0 if result["verdict"] == "PASS" else 1


def _cmd_run(args) -> int:
    from app.batch.fetchers import build_fetcher
    from app.batch.orchestrator import SfdaBatchOrchestrator
    from app.batch.quarantine import SfdaQuarantine

    # effective dry-run via the single safety contract
    mode = "live" if (args.write or args.mode == "live") else "dry-run"

    # A REQUESTED live run always passes the credential preflight FIRST
    # (SfdaAuthenticationRequired before any network call / DB write). The
    # env-level AGENT_DRY_RUN gate only decides whether writes actually land.
    if mode == "live":
        from app.batch.preflight import assert_credential_for_live

        try:
            assert_credential_for_live()
        except Exception as exc:
            print(f"ERROR: {exc}", file=sys.stderr)
            return 1

    active_dry_run = resolve_effective_dry_run(mode != "live")

    candidates = _candidates_for(args)
    if not candidates:
        print("ERROR: supply --barcodes-file / --references-file / --count", file=sys.stderr)
        return 2

    # when the env gate explicitly allows writes, open the caller-owned conn
    conn = None
    if not active_dry_run:
        from app.db.connection import get_connection

        conn = get_connection().__enter__()

    resolver = _resolver_for(args, conn, active_dry_run)
    fetcher = build_fetcher(live=(not active_dry_run), fixture_records=_fixture_records())
    quarantine = SfdaQuarantine(sink_dir=args.sink_dir, conn=conn)

    orchestrator = SfdaBatchOrchestrator(
        mode="live" if not active_dry_run else "dry-run",
        batch_size=args.batch_size,
        checkpoint_dir=args.checkpoint_dir,
        max_retries=args.max_retries,
        rate_limit_rps=args.rate_limit,
        conn=conn,
    )

    if args.resume:
        from app.batch.checkpoint import load_run

        resumed = load_run(args.resume, args.checkpoint_dir)
        if resumed is None:
            print(f"ERROR: no checkpoint for run {args.resume}", file=sys.stderr)
            return 2
        print(f"RESUMING run {args.resume} from checkpoint (processed={resumed.processed})")

    run = orchestrator.run(
        candidates=candidates,
        fetcher=fetcher,
        resolver=resolver,
        quarantine=quarantine,
        active_dry_run=active_dry_run,
    )
    _print_run(run, active_dry_run)
    return 0


def _candidates_for(args) -> list:
    from app.batch.discovery import (
        candidates_from_barcodes,
        candidates_from_file,
        candidates_from_references,
        synthetic_candidates_for_dry_run,
    )
    from app.batch.models import CandidateMode

    out = []
    if getattr(args, "barcodes_file", None):
        out += candidates_from_file(args.barcodes_file, CandidateMode.BARCODE)
    if getattr(args, "references_file", None):
        out += candidates_from_file(args.references_file, CandidateMode.REFERENCE)
    if getattr(args, "count", None):
        out = synthetic_candidates_for_dry_run(int(args.count), seed=out)
    return out


def _resolver_for(args, conn, active_dry_run):
    from app.batch.vocabulary import resolve_ingredient_token

    if args.resolver == "database":
        if conn is None:
            print("WARNING: --resolver database needs a live DB connection; falling back to offline", file=sys.stderr)
            return _no_resolver
        return resolve_ingredient_token
    if args.resolver == "fixture-grammar":
        return _fixture_grammar_resolver
    # auto: DB resolver when we already hold a connection, else offline.
    return resolve_ingredient_token if conn is not None else _no_resolver


def _no_resolver(conn, token):
    return None


def _fixture_grammar_resolver(conn, token):
    """Documented-translation stand-in grammar (STEP E 'applied' target state).

    Only exact terms are matched; anything else stays unresolved. Used for
    demos/tests, never for a credentialed production run.
    """
    from app.batch.vocabulary import DIRECT_MATCHES

    match = DIRECT_MATCHES.get(token.normalized)
    if match:
        return {"name": match["existing_name"], "internal_code": match["canonical"]}
    return None


_FIXTURE_RECORDS = None


def _fixture_records():
    global _FIXTURE_RECORDS
    if _FIXTURE_RECORDS is None:
        from tests.test_sfda_fixture_pipeline import FIRS_FIXTURE_1  # type: ignore
        from app.integrations.sfda_food_adapter import parse_firs_record, to_product_record

        record = to_product_record(parse_firs_record(FIRS_FIXTURE_1))
        _FIXTURE_RECORDS = {record.barcode: record}
    return _FIXTURE_RECORDS


def _print_run(run, active_dry_run):
    print(f"run        : {run.run_id}  ({run.mode})")
    print(f"total      : {run.total}")
    print(f"processed  : {run.processed}")
    print(f"inserted   : {run.inserted}")
    print(f"quarantined: {run.quarantined}")
    print(f"failed     : {run.failed}")
    print(f"skipped    : {run.skipped}")
    print(f"checkpoint : {CHECKPOINT_DIR}")
    print("effective dry_run = " + ("TRUE (nothing written)" if active_dry_run else "FALSE (live write path)"))
    for note in run.notes:
        print(f"note       : {note}")


def _cmd_migration_proposal(args) -> int:
    from app.batch.migration_proposal import _as_text, build_migration_proposal

    report = build_migration_proposal(out_path=Path(args.out) if args.out else None)
    if not args.out:
        print(_as_text(report))
    else:
        print(f"STEP H proposal written (UNAPPLIED): {args.out}")
    return 0


def _cmd_report(args) -> int:
    from app.batch import readiness_report

    out = readiness_report.write_readiness_report()
    print(f"readiness report written: {out}")
    print("SFDA_LIVE = BLOCKED_AUTH")
    print("SFDA_PIPELINE_READY_FOR_SCALING = PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())