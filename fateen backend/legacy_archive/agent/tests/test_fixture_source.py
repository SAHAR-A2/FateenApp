"""Tests for the offline synthetic-fixture mode.

Covers the FixtureSource and the full offline pipeline (fixture -> extraction
-> normalization -> matching/dedup -> conflict -> confidence -> verification
-> review) via the InMemoryRepository. No network and no database required.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from fateen_agent.config import Settings
from fateen_agent.db.inmemory import InMemoryRepository
from fateen_agent.pipeline.batch import BatchProcessor
from fateen_agent.pipeline.orchestrator import Orchestrator
from fateen_agent.sources.base import ProductQuery
from fateen_agent.sources.fixture import FixtureSource

FIXTURE = Path(__file__).parent / "fixtures" / "products_10.json"

EXPECTED = {
    "5901234123457": "VERIFIED",      # complete, matching sources
    "5901234123464": "NEEDS_REVIEW",  # missing ingredients
    "5901234123471": "CONFLICT",      # conflicting ingredients
    "5901234123488": "CONFLICT",      # conflicting allergens
    "5901234123495": "UNRESOLVED",    # not found
    "5901234123501": "VERIFIED",      # arabic product
    "5901234123518": "VERIFIED",      # english product
    "5901234123525": "NEEDS_REVIEW",  # barcode mismatch
    "5901234123549": "VERIFIED",      # label evidence
    "5901234123556": "VERIFIED",      # multiple sources, different priorities
}


def _queries() -> list[tuple[ProductQuery, str, str]]:
    return [(ProductQuery(barcode=k), k, "barcode") for k in EXPECTED]


@pytest.fixture()
def fixture_source() -> FixtureSource:
    return FixtureSource(FIXTURE)


def test_fixture_source_is_synthetic(fixture_source):
    assert fixture_source.meta["synthetic"] is True
    assert "NOT" in (fixture_source.meta.get("note") or "")
    assert fixture_source.health() is True


def test_fixture_source_searches_by_barcode(fixture_source):
    records = list(fixture_source.search(ProductQuery(barcode="5901234123457")))
    assert len(records) == 2
    names = {r.source.name for r in records}
    assert names == {"openfoodfacts", "manufacturer_official"}
    assert all(r.barcode == "5901234123457" for r in records)
    # all sources carry provenance
    assert all(r.source.source_type for r in records)
    assert all(r.source.priority for r in records)


def test_fixture_source_missing_case_returns_nothing(fixture_source):
    records = list(fixture_source.search(ProductQuery(barcode="5901234123495")))
    assert records == []


def test_fixture_source_unknown_barcode_returns_nothing(fixture_source):
    records = list(fixture_source.search(ProductQuery(barcode="0000000000000")))
    assert records == []


def test_offline_pipeline_expected_counts():
    repo = InMemoryRepository()
    batch_id = repo.start_batch("test_offline")
    orch = Orchestrator(repository=repo, sources=[FixtureSource(FIXTURE)], batch_id=batch_id, promote_verified=False)
    processor = BatchProcessor(
        process_one=orch.process,
        batch_label="test_offline",
        batch_id=batch_id,
        workers=1,
        retries=0,
        rate_limit_per_sec=1000.0,
        skip_processed=False,
        record_batch_item=repo.record_batch_item,
    )
    result = processor.run(_queries())

    by_key = {o.product_key: o for o in result.outcomes}
    assert len(by_key) == 10
    for key, expected in EXPECTED.items():
        assert by_key[key].status == expected, (
            f"{key}: expected {expected}, got {by_key[key].status} "
            f"(reason={by_key[key].review_task.reason if by_key[key].review_task else None})"
        )

    summary = result.summary
    assert summary.verified == 5
    assert summary.needs_review == 2
    assert summary.conflict == 2
    assert summary.unresolved == 1
    assert summary.failed == 0

    # Review queue: one task per non-verified product.
    assert len(repo.review_tasks) == 5
    # Nothing ever promoted / written to production.
    assert repo.promoted == []
    assert repo.batch_count == 1


def test_offline_pipeline_detects_barcode_mismatch():
    repo = InMemoryRepository()
    orch = Orchestrator(repository=repo, sources=[FixtureSource(FIXTURE)], promote_verified=False)
    outcome = orch.process(ProductQuery(barcode="5901234123525"), "5901234123525", "barcode")
    assert outcome.status == "NEEDS_REVIEW"
    assert any("Barcode mismatch" in n for n in (outcome.candidate.notes or []))
    assert outcome.review_task.reason.startswith("Barcode mismatch")


def test_offline_pipeline_flags_allergen_conflict():
    repo = InMemoryRepository()
    orch = Orchestrator(repository=repo, sources=[FixtureSource(FIXTURE)], promote_verified=False)
    outcome = orch.process(ProductQuery(barcode="5901234123488"), "5901234123488", "barcode")
    assert outcome.status == "CONFLICT"
    facts = {c.fact for c in (outcome.candidate.conflicts or [])}
    assert "allergens" in facts


def test_offline_pipeline_is_deterministic():
    runs = []
    for _ in range(3):
        repo = InMemoryRepository()
        orch = Orchestrator(repository=repo, sources=[FixtureSource(FIXTURE)], promote_verified=False)
        processor = BatchProcessor(
            process_one=orch.process,
            batch_label="determinism",
            workers=1,
            retries=0,
            rate_limit_per_sec=1000.0,
            skip_processed=False,
            record_batch_item=repo.record_batch_item,
        )
        result = processor.run(_queries())
        runs.append([(o.product_key, o.status, o.confidence) for o in result.outcomes])
    assert runs[0] == runs[1] == runs[2]


def test_offline_mode_sources_are_fixture_only():
    settings = Settings(live_web=False, fixture_path=str(FIXTURE))
    from fateen_agent.sources import default_sources

    sources = default_sources(settings)
    assert len(sources) == 1
    assert sources[0].name == "fixture"
