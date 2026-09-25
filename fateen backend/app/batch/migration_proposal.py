"""STEP H: migration proposal for the SFDA production path (README-ONLY).

HARD RULE: this module ONLY documents. It never executes a migration.

Decision (authoritative for the readiness report):
    CORE SFDA INGESTION PATH  -> NO migration required (STEP A rule). The
                                 batch pipeline is file-backed (checkpoints,
                                 quarantine JSONL) and reuses the existing
                                 provenance columns (evidence_type_id /
                                 source_id) already proven by the DB rollback
                                 tests.
    OPTIONAL QUARANTINE MIRROR -> migrations/0047_sfda_quarantine_candidates.sql
                                 (UNAPPLIED proposal) documents the exact
                                 shape IF a queryable quarantine table is
                                 wanted later. Pipeline works without it.
    STEP 3 data_source 'SFDA' -> deferred proposal (same file section) -
                                 required only for full provenance correctness,
                                 until then the placeholder source row is used
                                 in DB exercises.
"""
import logging
from pathlib import Path

from app.batch.models import utcnow

logger = logging.getLogger("fateen.batch.migration_proposal")

STEP_MIGRATION_VERSION = "sfda-step-h-proposal-1"

# The exact table the optional mirror would add (must match
# migrations/0047_sfda_quarantine_candidates.sql byte-for-byte).
QUARANTINE_TABLE_DDL = """
CREATE TABLE public.sfda_quarantine_candidates (
    id                      bigserial PRIMARY KEY,
    candidate_id            text        NOT NULL,
    identifier              text        NOT NULL,
    rejection_reasons       jsonb       NOT NULL DEFAULT '[]'::jsonb,
    unresolved_ingredients  jsonb       NOT NULL DEFAULT '[]'::jsonb,
    source                  text        NOT NULL DEFAULT 'SFDA'
                            CHECK (source IN ('SFDA')),
    processing_status       text        NOT NULL DEFAULT 'quarantined'
                            CHECK (processing_status IN ('quarantined','retried','resolved','discarded')),
    payload                 jsonb,
    created_at              timestamptz NOT NULL DEFAULT NOW(),
    updated_at              timestamptz NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_sfda_quarantine_identifier
    ON public.sfda_quarantine_candidates (identifier);
CREATE INDEX idx_sfda_quarantine_source_status
    ON public.sfda_quarantine_candidates (source, processing_status);
CREATE INDEX idx_sfda_quarantine_created_at
    ON public.sfda_quarantine_candidates (created_at DESC);
CREATE INDEX idx_sfda_quarantine_candidate_id
    ON public.sfda_quarantine_candidates (candidate_id);
"""

# The deferred STEP-3 row (also unapplied by design).
STEP3_DATA_SOURCE_DDL = """
-- Deferred (NEW STEP 3 proposal, NOT applied).
INSERT INTO public.data_sources (name, code, type_id, priority_id, is_active)
SELECT 'SFDA Registered Food Products', 'SFDA', st.id, sp.id, TRUE
  FROM public.source_types st, public.source_priorities sp
 WHERE st.code = 'REGULATORY' AND sp.code = 'REGULATORY'
    ON CONFLICT (code) DO NOTHING;
"""


def build_migration_proposal(out_path: Path | None = None) -> dict:
    """Return (and optionally persist) the full STEP H proposal document.

    Mandatory sections: why required / which table fails / exact
    columns+indexes+constraints / backward compatibility / rollback plan.
    """
    report = {
        "proposal_version": STEP_MIGRATION_VERSION,
        "generated_at": utcnow(),
        "summary": (
            "Core SFDA ingestion path requires NO migration; the optional "
            "quarantine mirror and the STEP-3 SFDA data_source row are "
            "documented proposals and are intentionally NOT applied."
        ),
        "migration_required_for_core_pipeline": "NO",
        "sections": {
            "why_required": (
                "The batch pipeline must not be blocked on schema work. "
                "Checkpoints and quarantine are file-backed today; DB "
                "mirroring is a retention/join convenience, not a dependency. "
                "The optional mirror exists so quarantine records can be "
                "queried and joined to products/ingredients for review, and so "
                "unresolved Arabic terms from live SFDA runs are preserved "
                "when the file sink is rotated."
            ),
            "which_table_fails": (
                "public.discovery_candidates (migration 002) is company-scoped "
                "(company_id) and carries no structured "
                "'unresolved_ingredients' column; public.data_conflicts is for "
                "cross-source conflicts, not per-candidate rejection with "
                "verbatim terms. Neither table can represent an SFDA "
                "quarantine row without shaping or losing data, so a "
                "dedicated table is the minimal, additive answer."
            ),
            "exact_columns_indexes_constraints": QUARANTINE_TABLE_DDL,
            "backward_compatibility": (
                "The table is brand new and references nothing existing; no "
                "existing query, trigger, or view depends on it. The file sink "
                "(sfda_quarantine.jsonl, append-only) remains the durable "
                "source of truth and is written FIRST on every "
                "quarantine.record() - the DB mirror fills in only when the "
                "table exists, so introducing or dropping the mirror never "
                "loses a record."
            ),
            "rollback_plan": (
                "DROP TABLE public.sfda_quarantine_candidates; the JSONL sink "
                "is untouched and keeps all records; the pipeline continues to "
                "run identically (the mirror is best-effort by design)."
            ),
            "step3_sfda_source": {
                "migration_required_for_core_pipeline": "NO",
                "why_required": (
                    "full provenance correctness: SFDA-sourced product_ingredients/"
                    "product_barcodes should reference data_sources.code='SFDA' "
                    "instead of the OPEN_FOOD_FACTS placeholder used in DB "
                    "exercises today."
                ),
                "ddl": STEP3_DATA_SOURCE_DDL,
                "backward_compatibility": (
                    "an additive source-type row; no existing data references "
                    "it (there are no SFDA rows yet), so nothing breaks."
                ),
                "rollback_plan": (
                    "DELETE FROM public.data_sources WHERE code='SFDA'; any "
                    "SFDA rows would need re-pointing - which is why the "
                    "proposal must run together with the first credentialed "
                    "ingestion, never before."
                ),
            },
        },
        "must_not_execute": True,
    }
    if out_path:
        Path(out_path).parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(_as_text(report))
        logger.info("migration proposal written (unapplied): %s", out_path)
    return report


def _as_text(report: dict) -> str:
    sections = report["sections"]
    lines = [
        "STEP H - SFDA MIGRATION PROPOSAL (UNAPPLIED)",
        "=" * 60,
        "",
        f"proposal version : {report['proposal_version']}",
        f"generated at     : {report['generated_at']}",
        f"core pipeline    : migration required = {report['migration_required_for_core_pipeline']}",
        f"proposals executed = {report['must_not_execute'] == False}",
        "",
        "SUMMARY",
        report["summary"],
        "",
        "WHY REQUIRED",
        sections["why_required"],
        "",
        "WHICH TABLE FAILS / WHY NOT EXISTING TABLES",
        sections["which_table_fails"],
        "",
        "EXACT COLUMNS + INDEXES + CONSTRAINTS (0047 proposal)",
        sections["exact_columns_indexes_constraints"],
        "",
        "BACKWARD COMPATIBILITY",
        sections["backward_compatibility"],
        "",
        "ROLLBACK PLAN",
        sections["rollback_plan"],
        "",
        "STEP 3 - SFDA DATA_SOURCE (DEFERRED PROPOSAL)",
        f"  required for core pipeline : {sections['step3_sfda_source']['migration_required_for_core_pipeline']}",
        f"  why                        : {sections['step3_sfda_source']['why_required']}",
        "  ddl (unapplied):",
        sections["step3_sfda_source"]["ddl"],
        f"  backward compatibility     : {sections['step3_sfda_source']['backward_compatibility']}",
        f"  rollback plan              : {sections['step3_sfda_source']['rollback_plan']}",
        "",
    ]
    return "\n".join(lines)