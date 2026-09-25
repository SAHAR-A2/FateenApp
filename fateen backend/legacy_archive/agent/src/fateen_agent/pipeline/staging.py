"""Staging: persist raw source payloads for the audit trail."""

from __future__ import annotations

from typing import Iterable, Optional

from ..db.repository import FateenRepository
from ..models import RawProductData


def stage_all(
    repo: FateenRepository,
    batch_id: Optional[str],
    product_key: str,
    key_type: str,
    records: Iterable[RawProductData],
) -> int:
    """Write every raw record to agent.staged_findings. Returns count."""
    n = 0
    for record in records:
        try:
            repo.stage_finding(
                batch_id=batch_id,
                product_key=product_key,
                key_type=key_type,
                source=record.source,
                raw=record.raw,
            )
            n += 1
        except Exception:  # noqa: BLE001 — staging must not kill the product
            continue
    return n
