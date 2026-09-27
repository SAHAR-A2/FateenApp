"""Ledger planning rules of scripts/migrate.py (pure, no database)."""
import importlib.util
import sys
from pathlib import Path

import pytest

_SPEC = importlib.util.spec_from_file_location(
    "migrate", Path(__file__).resolve().parent.parent / "scripts" / "migrate.py"
)
migrate = importlib.util.module_from_spec(_SPEC)
sys.modules["migrate"] = migrate  # dataclasses resolve their module by name
_SPEC.loader.exec_module(migrate)


@pytest.fixture(scope="module")
def migrations():
    return migrate.discover()


def _full_ledger(migrations):
    ledger = {}
    for m in migrations:
        if m.self_registers:
            ledger[m.stem] = "fateen-pilot-label"
        else:
            ledger[m.version] = m.checksum
    return ledger


def test_repository_migrations_are_ordered_and_unique(migrations):
    names = [m.version for m in migrations]
    assert names[0] == migrate.BASELINE
    assert len(set(m.order for m in migrations)) == len(migrations)


def test_checksum_matches_legacy_ledger_format():
    # Recorded for 0001 in docs/12_migrations.txt by the legacy migrate.ps1.
    legacy = migrate.Migration(
        "0001_foundation_extensions.sql",
        migrate.LEGACY_DIR / "0001_foundation_extensions.sql",
        1,
    )
    assert legacy.checksum == "25cc78dc2c82da967b3ed1338b0f1087"


def test_empty_ledger_everything_pending(migrations):
    p = migrate.plan(migrations, {})
    assert p.pending == migrations
    assert not (p.applied or p.mismatched or p.unknown)


def test_fully_applied_ledger_is_consistent(migrations):
    p = migrate.plan(migrations, _full_ledger(migrations))
    assert not (p.pending or p.mismatched or p.unknown or p.legacy_missing)


def test_modified_file_is_detected(migrations):
    ledger = _full_ledger(migrations)
    victim = next(m for m in migrations if not m.self_registers)
    ledger[victim.version] = "0" * 32
    assert migrate.plan(migrations, ledger).mismatched == [victim]


def test_cloud_like_ledger_reports_missing_files(migrations):
    """Cloud carries the legacy chain plus migrations never committed here."""
    ledger = {v: "0" * 32 for v in migrate.legacy_chain()}
    ledger["0052_grant_fateen_app_phase12_write_path.sql"] = "1" * 32
    p = migrate.plan(migrations, ledger)
    assert p.baseline_via_legacy
    assert migrate.BASELINE in [m.version for m in p.applied]
    assert p.unknown == ["0052_grant_fateen_app_phase12_write_path.sql"]


def test_partial_legacy_chain_is_a_gap(migrations):
    ledger = {v: "0" * 32 for v in sorted(migrate.legacy_chain())[:5]}
    p = migrate.plan(migrations, ledger)
    assert not p.baseline_via_legacy
    assert p.legacy_missing


def test_pg17_only_statements_stripped_for_older_servers():
    text = "\\restrict abc\nSET transaction_timeout = 0;\nSELECT 1;\n\\unrestrict abc\n"
    assert migrate._prepare_sql(text, 160000).split() == ["SELECT", "1;"]
    assert "transaction_timeout" in migrate._prepare_sql(text, 170000)


def test_recorded_cloud_ledger_snapshot(migrations):
    """Replay the read-only Cloud ledger snapshot kept in docs/."""
    import json

    snapshot = json.loads(
        (migrate.BACKEND_ROOT / "docs" / "phase5c_phase6_cloud_introspection.json").read_text()
    )["migrations"]
    assert len(snapshot) == 51
    # The snapshot lists versions only; 0042/0043 carry labels on Cloud.
    ledger = {v: "fateen-pilot-label" for v in snapshot}
    p = migrate.plan(migrations, ledger)

    assert p.baseline_via_legacy
    assert {m.version for m in p.unverified} == {
        "0042_pilot_source_priorities_seed.sql",
        "0043_pilot_provider_failure_statuses.sql",
    }
    assert [m.version for m in p.pending] == [
        "003_pilot_constraints.sql",
        "0053_restore_fateen_app_history_write_path.sql",
        "0054_product_completeness_view.sql",
    ]
    assert p.unknown == [
        "0040_security_hardening.sql",
        "0041",
        "0044_open_food_facts_source",
        "0045_open_food_facts_reference_ingredients",
        "0046_off_nutrition_reference_salt",
        "0048_off_pilot_reference_ingredients",
        "0049_off_pilot_reference_ingredients",
        "0050_off_pilot_reference_ingredients",
        "0051_off_pilot_reference_ingredients.sql",
    ]
