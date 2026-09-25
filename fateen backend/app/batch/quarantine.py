"""Quarantine sink for rejected/unresolved SFDA candidates.

Augments the existing discovery/quarantine architecture rather than replacing
it: the collector's `discovery_candidates` table is company-scoped and carries
no structured 'unresolved ingredients' column, so SFDA quarantine persists to a
file sink today (append-only JSONL). If the proposed DB table from
migrations/0047_sfda_quarantine_candidates.sql (unapplied) is present, records
are ALSO mirrored there. No migration is applied by this code.
"""
import json
import logging
from pathlib import Path
from typing import Optional

from app.batch.models import QuarantineRecord

logger = logging.getLogger("fateen.batch.quarantine")

QUARANTINE_TABLE = "sfda_quarantine_candidates"


class SfdaQuarantine:
    def __init__(self, sink_dir: str | Path, conn=None):
        self.sink_dir = Path(sink_dir)
        self.sink_dir.mkdir(parents=True, exist_ok=True)
        self._conn = conn
        self._records: list[QuarantineRecord] = []

    @property
    def table_exists(self) -> bool:
        if self._conn is None:
            return False
        row = self._conn.execute(
            "SELECT to_regclass(%s)", ("public." + QUARANTINE_TABLE,)
        ).fetchone()
        return bool(row and row[0])

    def record(self, record: QuarantineRecord) -> None:
        self._records.append(record)
        with open(self.sink_dir / "sfda_quarantine.jsonl", "a", encoding="utf-8") as f:
            f.write(json.dumps(record.__dict__, ensure_ascii=False, default=str) + "\n")
        if self.table_exists:
            self._db_insert(record)
        else:
            logger.info(
                "quarantine sink = file (DB table %s not present; apply "
                "migrations/0047 proposal for DB mirroring)",
                QUARANTINE_TABLE,
            )

    def _db_insert(self, record: QuarantineRecord) -> None:
        rows = self._conn.execute(
            f"""
            INSERT INTO public.{QUARANTINE_TABLE}
                (candidate_id, identifier, rejection_reasons, unresolved_ingredients,
                 source, processing_status, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW(), NOW())
            """,
            (
                record.candidate_id,
                record.identifier,
                json.dumps(record.reasons, ensure_ascii=False),
                json.dumps(record.unresolved_ingredients, ensure_ascii=False),
                record.source,
                record.processing_status,
            ),
        )

    def records(self) -> list[dict]:
        return [r.__dict__ for r in self._records]

    def count(self) -> int:
        return len(self._records)