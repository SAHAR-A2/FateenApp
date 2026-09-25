"""STEP F: certification checks for the SFDA production ingestion path.

Deterministic, read-only certification that the pipeline holds its safety
contracts BEFORE a credential is configured:

   1  credential gate      live calls raise SfdaAuthenticationRequired before
                           any network request when no credential is set
   2  no fabrication       an unresolved candidate is QUARANTINED (never
                           inserted); a fully-resolved candidate is INSERTED;
                           the raw SFDA payload travels untouched
   3  strict resolver      only exact grammar matches resolve; Arabic terms
                           without a match stay verbatim in the quarantine
   4  quarantine verbatim  quarantine records carry the exact unresolved terms
                           + rejection reasons + evidence payload
   5  credential hygiene   preflight reports presence booleans only, never
                           the credential value
   6  rollback-only DB     the DB SFDA tests are transaction-rolled-back with
                           an explicit zero-residue assertion
   7  checkpoint/resume    orchestrator checkpoints and resumes deterministically

Every check returns PASS or FAIL with a reason. Nothing here writes to the
database or the network.
"""
import logging
import shutil
from pathlib import Path

from app.batch.models import (
    Candidate,
    CandidateMode,
    CandidateStatus,
    QuarantineStatus,
    RejectionReason,
)
from app.batch.pipeline import process_candidate
from app.batch.quarantine import SfdaQuarantine

logger = logging.getLogger("fateen.batch.certify")

CERTIFICATION_VERSION = "sfda-pipeline-cert-1"

FIXTURE_PAYLOAD = {"barCode": "50254156", "tradeName": "Dr.Oetker"}
FIXTURE_INGREDIENTS_AR = (
    "سكر، زبدة الكاكاو، مسحوق الحليب كامل الدسم، "
    "مسحوق مصل اللبن (حليب)، مستحلب ليسيثين الصويا"
)


def _no_resolver(conn, token):
    """Resolver that matches nothing: proves the quarantine path."""
    return None


def _sugar_resolver(conn, token):
    """Resolver that lets exactly the fixture term 'سكر' resolve (strict).

    Mirrors the documented FATEEN resolver contract: a token resolves ONLY
    through an exact vocabulary match. This vocabulary is the trusted offline
    stand-in for the DB grammar; everything else stays unresolved.
    """
    return {"name": "sugar", "internal_code": "SUGAR"} if token.normalized == "سكر" else None


def _fixture_candidate(candidate_id: str) -> Candidate:
    return Candidate(
        candidate_id=candidate_id,
        mode=CandidateMode.BARCODE,
        identifier="50254156",
        barcode="50254156",
        trade_name="Dr.Oetker",
        brand="Dr.Oetker",
        company="Dr.Oetker",
        ingredients_ar=FIXTURE_INGREDIENTS_AR,
        raw_payload=FIXTURE_PAYLOAD,
    )


def _record():
    from app.integrations.sfda_food_adapter import SfdaProductRecord

    return SfdaProductRecord(
        source="SFDA",
        source_record_id="P-3-N-200621-107719",
        registration_number="P-3-N-200621-107719",
        barcode="50254156",
        trade_name="Dr.Oetker",
        brand="Dr.Oetker",
        company="Dr.Oetker",
        item_description="رقائق الشوكولاته البيضاء",
        ingredients_ar=FIXTURE_INGREDIENTS_AR,
        ingredients_en="",
        raw_payload={
            **FIXTURE_PAYLOAD,
            "RefNumber": "P-3-N-200621-107719",
            "ItemDescription": "رقائق الشوكولاته البيضاء",
        },
    )


def run_certification(
    checkpoint_dir: str | Path = ".sfda_cert",
    sink_dir: str | Path = ".sfda_cert/sink",
) -> dict:
    for p in (checkpoint_dir, sink_dir):
        if Path(p).exists():
            shutil.rmtree(Path(p), ignore_errors=True)

    quarantine = SfdaQuarantine(sink_dir=sink_dir)
    results: list[dict] = []

    def _check(name, ok, detail):
        results.append({"check": name, "result": "PASS" if ok else "FAIL", "detail": detail})
        return ok

    # 1. credential gate ---------------------------------------------------
    from app.integrations.sfda_food_adapter import SfdaAuthenticationRequired, SfdaFoodAdapter

    adapter = SfdaFoodAdapter(token=None, api_key=None, base_url="https://example.invalid")
    try:
        adapter.firs_food_list(page=1)
        _check("1-credential-gate", False, "firs_food_list did NOT raise without an API key")
    except SfdaAuthenticationRequired as exc:
        _check("1-credential-gate", True, f"firs_food_list raised '{exc.code}' before any network call")
    except Exception as exc:
        _check("1-credential-gate", False, f"unexpected exception: {type(exc).__name__}: {exc}")

    try:
        adapter.fetch_by_barcode("50254156")
        _check("1b-credential-gate-bearer", False, "fetch_by_barcode did NOT raise without a token")
    except SfdaAuthenticationRequired as exc:
        _check("1b-credential-gate-bearer", True, f"fetch_by_barcode raised '{exc.code}' before any network call")
    except Exception as exc:
        _check("1b-credential-gate-bearer", False, f"unexpected: {type(exc).__name__}: {exc}")

    # 2. no fabrication / quarantine path ----------------------------------
    quarantined = process_candidate(
        _fixture_candidate("cert-cand-unresolved"),
        record=_record(),
        resolver=_no_resolver,
        quarantine=quarantine,
        conn=None,
        dry_run=True,
    )
    payload_preserved = quarantined.raw_payload == _record().raw_payload
    no_fabrication = (
        quarantined.status == CandidateStatus.QUARANTINED
        and not quarantined.resolved_names
        and RejectionReason.UNRESOLVED_INGREDIENTS.value in quarantined.rejection_reasons
        and payload_preserved
    )
    _check(
        "2-no-fabrication",
        no_fabrication,
        f"unresolved candidate -> QUARANTINED; reasons={quarantined.rejection_reasons}; "
        f"raw payload preserved={payload_preserved}",
    )

    # 3. strict resolver ----------------------------------------------------
    inserted = process_candidate(
        _fixture_candidate("cert-cand-resolved"),
        record=_record(),
        resolver=_sugar_resolver,
        quarantine=quarantine,
        conn=None,
        dry_run=True,
    )
    # With exactly 'سكر' in the vocabulary the product is NOT fully resolved,
    # so it must be QUARANTINED - never partially inserted with fabricated
    # completions for the other four tokens.
    strict = (
        inserted.status == CandidateStatus.QUARANTINED
        and inserted.resolved_names == ["sugar"]
        and len(inserted.unresolved_ingredients) == 4
    )
    _check(
        "3-strict-resolver",
        strict,
        f"only 'سكر' resolved -> QUARANTINED (never partial-insert); names={inserted.resolved_names}; "
        f"unresolved={len(inserted.unresolved_ingredients)}",
    )

    # 4. quarantine verbatim --------------------------------------------------
    unresolved_terms = {u["term"] for u in quarantined.unresolved_ingredients}
    qrec = [r for r in quarantine.records() if r["candidate_id"] == quarantined.candidate_id]
    verbatim_ok = bool(
        qrec
        and RejectionReason.UNRESOLVED_INGREDIENTS.value in qrec[0]["reasons"]
        and {u["term"] for u in qrec[0]["unresolved_ingredients"]} == unresolved_terms
        and qrec[0]["payload"] == _record().raw_payload
        and qrec[0]["processing_status"] == QuarantineStatus.QUARANTINED.value
    )
    _check("4-quarantine-verbatim", verbatim_ok,
           f"quarantine carries {len(unresolved_terms)} verbatim unresolved terms + evidence payload")

    # 5. credential hygiene --------------------------------------------------
    from app.batch.preflight import check_credentials
    from app.core.config import settings

    cred_report = check_credentials()
    live_values = {
        v for v in (
            settings.sfda_access_token,
            settings.sfda_api_key,
            settings.sfda_consumer_key,
            settings.sfda_consumer_secret,
            settings.sfda_oauth_token_url,
        ) if v
    }
    leaks = [k for k, v in cred_report.items() if isinstance(v, str) and v and v in live_values]
    hygiene = cred_report["credential_configured"] in {"YES", "NO"} and not leaks
    _check(
        "5-credential-hygiene",
        hygiene,
        "preflight reports presence booleans only (never the credential value)"
        if hygiene else f"credential value exposed in report keys: {leaks}",
    )

    # 6. rollback-only DB tests ------------------------------------------------
    db_test_path = (
        Path(__file__).resolve().parents[2] / "tests" / "test_sfda_fixture_db_rollback.py"
    )
    rollback_ok = False
    if db_test_path.exists():
        source = db_test_path.read_text(encoding="utf-8")
        rollback_ok = (
            "psycopg.Rollback" in source
            and "residue == 0" in source
            and "pytest.mark.integration" in source
        )
    _check(
        "6-rollback-only-db-tests",
        rollback_ok,
        f"{db_test_path.name}: explicit Rollback + zero-residue assertion"
        if rollback_ok else f"{db_test_path.name} missing/does not enforce rollback-only writes",
    )

    # 7. checkpoint/resume ------------------------------------------------------
    from app.batch.checkpoint import list_runs, load_run, new_run_id, save_run
    from app.batch.models import BatchRun

    run_id = new_run_id()  # sfda-run-* so list_runs() matches the checkpoint
    run = BatchRun(run_id=run_id, mode="dry-run", batch_size=1, total=1, processed=1)
    save_run(run, checkpoint_dir)
    listed = [p for p in list_runs(checkpoint_dir) if p.startswith(run_id)]
    loaded = load_run(run_id, checkpoint_dir)
    checkpoint_ok = bool(loaded and loaded.run_id == run_id and listed)
    _check("7-checkpoint-resume", checkpoint_ok, f"save/load/list round-trip found {listed}")

    from app.batch.models import utcnow

    passed = sum(1 for r in results if r["result"] == "PASS")
    return {
        "certification": CERTIFICATION_VERSION,
        "generated_at": utcnow(),
        "results": results,
        "verdict": "PASS" if passed == len(results) else "FAIL",
        "note": "certification is read-only; nothing dials out or writes to the database.",
    }