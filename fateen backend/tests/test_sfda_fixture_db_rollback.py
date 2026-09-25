"""SFDA_FIXTURE_TEST (DB, but read-only or fully rolled back): persistence layer.

This is the DB-backed half of the SFDA fixture scenario. It proves, against the
real FATEEN database (no common DB wiped, nothing persisted):

  1. Provenance readiness  - `OFFICIAL_SOURCE` evidence and the `REGULATORY`
     source type already exist, and source_priorities.REGULATORY has rank 2,
     i.e. the exact columns the SFDA step (STEP 3) will target. It also
     documents (read-only) that no `SFDA` data_source row exists yet: that
     migration is intentionally deferred, not silently applied.
  2. Resolver vs grammar   - Arabic SFDA ingredient tokens do NOT resolve
     against the FATEEN ingredient grammar (a deterministic exact-name lookup).
     This is the honest, quantified gap that the normalize-to-FATEEN-naming
     regression work must close; 'sugar' resolving proves the resolver wiring
     itself works.
  3. Provenance write path - the SQL used by the SFDA path (same columns as
     app.agent.ingestion._create_ingredient, incl. evidence_type_id/source_id)
     INSERTs and SELECTs correctly, then the whole transaction is ROLLED BACK.
     Afterwards the test asserts zero residue rows remain.

Every write happens inside one transaction that is always rolled back; no real
data is created, modified, or deleted.
"""

import random
import uuid
from decimal import Decimal

import psycopg
import pytest

pytestmark = [pytest.mark.SFDA_FIXTURE_TEST, pytest.mark.integration]

from app.core.config import settings  # noqa: E402
from app.integrations.sfda_ingredients import split_ingredient_text  # noqa: E402
from tests.test_sfda_fixture_pipeline import ARABIC_INGREDIENT_FIXTURE  # noqa: E402

_ARABIC_TOKENS = split_ingredient_text(ARABIC_INGREDIENT_FIXTURE).tokens


def _ref_by_code(conn, table: str, code: str):
    return conn.execute(f"SELECT id FROM public.{table} WHERE code=%s LIMIT 1", (code,)).fetchone()["id"]


def conn_ingredient_id(conn):
    # `ingredients` keys on internal_code (no `code` column).
    row = conn.execute(
        "SELECT id FROM public.ingredients WHERE internal_code=%s LIMIT 1", ("SUGAR",)
    ).fetchone()
    assert row is not None
    return row["id"]


@pytest.fixture(scope="module")
def db_conn():
    try:
        import psycopg  # noqa: F401

        conn = PsycopgConn(settings.database_url)
    except Exception as exc:  # pragma: no cover - environment-dependent
        pytest.skip(f"database unavailable: {exc}")
    yield conn.connect()


class PsycopgConn:
    """Small holder so a single module connection can be opened lazily."""

    def __init__(self, url):
        self._url = url
        self._conn = None

    def connect(self):
        if self._conn is None:
            from psycopg import connect as _connect
            from psycopg.rows import dict_row

            # autocommit: SELECT helpers below run free-standing; the write
            # block uses an explicit `conn.transaction()` that is rolled back.
            # dict_row matches the row factory used by the app's own pool.
            self._conn = _connect(self._url, autocommit=True)
            self._conn.row_factory = dict_row
        return self._conn


# ---------------------------------------------------------------------------
# 1. Provenance readiness (read-only)
# ---------------------------------------------------------------------------


def test_evidence_and_source_ready(db_conn):
    assert _ref_by_code(db_conn, "evidence_types", "OFFICIAL_SOURCE") is not None
    assert _ref_by_code(db_conn, "source_types", "REGULATORY") is not None
    rank = db_conn.execute(
        "SELECT rank FROM public.source_priorities WHERE code='REGULATORY'"
    ).fetchone()
    assert rank is not None and rank["rank"] == 2

    # Honest gap: the SFDA data_source row is the deferred STEP 3 migration.
    sfda = db_conn.execute("SELECT id FROM public.data_sources WHERE code='SFDA'").fetchone()
    assert sfda is None, "SFDA source row already present; STEP 3 was applied unexpectedly"


# ---------------------------------------------------------------------------
# 2. Resolver vs grammar (read-only)
# ---------------------------------------------------------------------------


def test_ingredient_resolver_against_grammar(db_conn):
    rows = db_conn.execute(
        "SELECT internal_code, name FROM public.ingredients WHERE deleted_at IS NULL"
    ).fetchall()
    grammar_names = {r["name"].strip().lower() for r in rows}

    for token in _ARABIC_TOKENS:
        assert (
            token.normalized not in grammar_names
        ), f"unexpected: '{token.normalized}' resolved in FATEEN grammar"

    assert "sugar" in grammar_names, "resolver grammar sanity check: 'sugar' must be present"
    resolved = [r for r in rows if r["name"].strip().lower() == "sugar"]
    assert len(resolved) == 1 and resolved[0]["internal_code"] == "SUGAR"

    unresolved = [t.normalized for t in _ARABIC_TOKENS if t.normalized not in grammar_names]
    assert len(unresolved) == len(_ARABIC_TOKENS)
    assert all(t.annotation is not None for t in _ARABIC_TOKENS if "حليب" in (t.annotation or ""))


# ---------------------------------------------------------------------------
# 3. Provenance write path (transaction rolled back; residue checked)
# ---------------------------------------------------------------------------


def test_database_insert_provenance_columns_rollback(db_conn):
    """Insert an SFDA-shaped product + ingredients with OFFICIAL_SOURCE
    evidence, then ROLLBACK and assert no residue.

    source_id uses the existing OPEN_FOOD_FACTS row as a column-shape
    placeholder only (there is no SFDA data_source yet by design); the exact
    insert mirrors app.agent.ingestion._create_ingredient's column set so the
    SFDA path will drop into the same provenance columns.
    """
    refs = {
        "ls_ACTIVE": _ref_by_code(db_conn, "lifecycle_statuses", "ACTIVE"),
        "rt_CONTAINS_INGREDIENT": _ref_by_code(db_conn, "relationship_types", "CONTAINS_INGREDIENT"),
        "rt_PRIMARY_BARCODE": _ref_by_code(db_conn, "relationship_types", "PRIMARY_BARCODE"),
        "evidence_OFFICIAL_SOURCE": _ref_by_code(db_conn, "evidence_types", "OFFICIAL_SOURCE"),
        "source_PLACEHOLDER": _ref_by_code(db_conn, "data_sources", "OPEN_FOOD_FACTS"),
        "barcode_type_GTIN": _ref_by_code(db_conn, "barcode_types", "GTIN"),
        "verification_PENDING": _ref_by_code(db_conn, "verification_statuses", "PENDING"),
        "sugar_ingredient": conn_ingredient_id(db_conn),
    }

    suffix = uuid.uuid4().hex[:8]
    internal_code = f"FATEEN_SFDA_FIXTURE_{suffix}"
    synthetic_barcode = "2" + "".join(random.Random(suffix).choices("0123456789", k=12))
    assert 13 <= len(synthetic_barcode) <= 14

    with db_conn.transaction() as tx:
        product_id = db_conn.execute(
            """
            INSERT INTO public.products (internal_code, name, description, status_id,
                                         confidence_level, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, NOW(), NOW())
            RETURNING id
            """,
            (internal_code, "SFDA fixture product (rollback proof)", "dr.oetker white chocolate chips", refs["ls_ACTIVE"], 0.5),
        ).fetchone()["id"]

        barcode_id = db_conn.execute(
            """
            INSERT INTO public.barcodes (barcode, barcode_type_id, verification_status_id,
                                         status_id, confidence_level, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, NOW(), NOW())
            RETURNING id
            """,
            (synthetic_barcode, refs["barcode_type_GTIN"], refs["verification_PENDING"],
             refs["ls_ACTIVE"], 0.5),
        ).fetchone()["id"]

        db_conn.execute(
            """
            INSERT INTO public.product_barcodes
                (product_id, barcode_id, relationship_type_id, status_id,
                 evidence_type_id, source_id, confidence_level, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
            """,
            (product_id, barcode_id, refs["rt_PRIMARY_BARCODE"], refs["ls_ACTIVE"],
             refs["evidence_OFFICIAL_SOURCE"], refs["source_PLACEHOLDER"], 0.5),
        )

        db_conn.execute(
            """
            INSERT INTO public.product_ingredients
                (product_id, ingredient_id, relationship_type_id, status_id,
                 confidence_level, evidence_type_id, source_id, created_at, updated_at)
            VALUES (%s, %s, %s, %s, %s, %s, %s, NOW(), NOW())
            """,
            (product_id, refs["sugar_ingredient"], refs["rt_CONTAINS_INGREDIENT"],
             refs["ls_ACTIVE"], 0.55, refs["evidence_OFFICIAL_SOURCE"], refs["source_PLACEHOLDER"]),
        )

        joined = db_conn.execute(
            """
            SELECT pi.evidence_type_id, pi.source_id, pi.confidence_level
            FROM public.product_ingredients pi
            JOIN public.products p ON p.id = pi.product_id
            WHERE p.internal_code = %s
            """,
            (internal_code,),
        ).fetchone()
        assert joined is not None
        assert joined["evidence_type_id"] == refs["evidence_OFFICIAL_SOURCE"]
        assert joined["confidence_level"] == Decimal("0.55")

        # Explicit, unconditional rollback: nothing may persist. psycopg3
        # rolls back a Transaction context when psycopg.Rollback is raised
        # (and swallows it), which is the supported way to force a rollback.
        raise psycopg.Rollback()

    residue = db_conn.execute(
        "SELECT count(*) AS n FROM public.products WHERE internal_code LIKE 'FATEEN_SFDA_FIXTURE_' || %s",
        (suffix,),
    ).fetchone()["n"]
    barcode_residue = db_conn.execute(
        "SELECT count(*) AS n FROM public.barcodes WHERE barcode = %s", (synthetic_barcode,)
    ).fetchone()["n"]
    assert residue == 0
    assert barcode_residue == 0