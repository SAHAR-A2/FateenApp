"""Checkpoint store for the SFDA batch orchestrator.

File-backed, JSON, atomic writes, resume-friendly. No database migration is
required for checkpointing (STEP A: do not require a migration unless the
schema genuinely cannot support it).
"""
import json
import logging
import os
import tempfile
import time
import uuid
from pathlib import Path

from app.batch.models import BatchRun, utcnow

logger = logging.getLogger("fateen.batch.checkpoint")

DEFAULT_CHECKPOINT_DIR = ".sfda_batch"


def new_run_id() -> str:
    return "sfda-run-" + uuid.uuid4().hex[:8]


def checkpoint_path_for(run_id: str, checkpoint_dir: str | Path) -> Path:
    return Path(checkpoint_dir) / f"{run_id}.json"


def _atomic_write(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2, default=str)
        # Windows: rapid in-place os.replace() can transiently hit an AV /
        # Defender read-lock on the destination; retry briefly instead of
        # failing a checkpoint write out of the blue.
        last_error = None
        for _ in range(5):
            try:
                os.replace(tmp, str(path))
                return
            except PermissionError as exc:
                last_error = exc
                time.sleep(0.05)
        raise last_error
    finally:
        if os.path.exists(tmp):
            try:
                os.remove(tmp)
            except OSError:
                pass


def save_run(run: BatchRun, checkpoint_dir: str | Path) -> Path:
    path = checkpoint_path_for(run.run_id, checkpoint_dir)
    payload = run.to_dict()
    payload["updated_at"] = utcnow()
    _atomic_write(path, payload)
    logger.info("checkpoint saved: %s (%d/%d)", path, run.processed, run.total)
    return path


def load_run(run_id: str, checkpoint_dir: str | Path) -> BatchRun | None:
    path = checkpoint_path_for(run_id, checkpoint_dir)
    if not path.exists():
        return None
    with open(path, encoding="utf-8") as f:
        payload = json.load(f)
    run = BatchRun.from_dict(payload)
    logger.info("checkpoint loaded: %s", path)
    return run


def list_runs(checkpoint_dir: str | Path) -> list[str]:
    root = Path(checkpoint_dir)
    if not root.exists():
        return []
    return sorted(p.name for p in root.glob("sfda-run-*.json"))


def create_run(mode: str, batch_size: int, checkpoint_dir: str | Path) -> BatchRun:
    run = BatchRun(run_id=new_run_id(), mode=mode, batch_size=batch_size, total=0)
    save_run(run, checkpoint_dir)
    return run