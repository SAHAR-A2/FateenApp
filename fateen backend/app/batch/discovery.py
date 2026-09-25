"""Discovery stage: candidate queue for the SFDA batch pipeline.

Discovery is deliberately SEPARATE from production insertion (STEP B): the
queue accepts barcodes / reference numbers / search terms / listing inputs and
produces `Candidate` objects. Production ingestion consumes the queue; nothing
here writes to the products graph.
"""
import logging
import uuid
from pathlib import Path
from typing import Iterable, Optional

from app.batch.models import Candidate, CandidateMode

logger = logging.getLogger("fateen.batch.discovery")


def _candidate(mode: CandidateMode, identifier: str) -> Candidate:
    return Candidate(
        candidate_id=uuid.uuid4().hex,
        mode=mode,
        identifier=str(identifier).strip(),
    )


def candidates_from_file(path: str | Path, mode: CandidateMode) -> list[Candidate]:
    """One candidate per non-empty, non-comment line of a plain-text file."""
    out: list[Candidate] = []
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            out.append(_candidate(mode, line))
    logger.info("loaded %d candidates from %s (%s)", len(out), path, mode.value)
    return out


def candidates_from_barcodes(barcodes: Iterable[str]) -> list[Candidate]:
    return [_candidate(CandidateMode.BARCODE, b) for b in barcodes]


def candidates_from_references(references: Iterable[str]) -> list[Candidate]:
    return [_candidate(CandidateMode.REFERENCE, r) for r in references]


def candidates_from_keywords(keywords: Iterable[str]) -> list[Candidate]:
    return [_candidate(CandidateMode.SEARCH, k) for k in keywords]


def candidates_from_pages(pages: Iterable[int]) -> list[Candidate]:
    return [_candidate(CandidateMode.LIST, str(p)) for p in pages]


def synthetic_candidates_for_dry_run(total: int, seed: list[Candidate]) -> list[Candidate]:
    """Deterministic dry-run queue (no network, no fabricated records).

    Cycles the provided seed candidates and appends clearly-synthetic pending
    candidates so checkpointing / retry / rate-limit / resume mechanics can be
    exercised end-to-end without inventing SFDA data. Synthetic identifiers use
    the 'FIXTURE-NOTFETCHED-' prefix and can never resolve (the fetch stage
    returns 'no record' for them), which is the honest offline equivalent.
    """
    out: list[Candidate] = []
    base = len(seed) if seed else 1
    for i in range(total):
        if seed and i < len(seed):
            out.append(seed[i])
        else:
            out.append(
                Candidate(
                    candidate_id=uuid.uuid4().hex,
                    mode=CandidateMode.BARCODE,
                    identifier=f"FIXTURE-NOTFETCHED-{i % max(base, 1)}",
                )
            )
    logger.info("built dry-run queue of %d candidates", len(out))
    return out