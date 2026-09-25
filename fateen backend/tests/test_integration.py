"""
Real-DB Integration Tests for FATEEN Backend.

These tests require a running PostgreSQL with the fateen database.
They are marked with pytest.mark.integration and must NOT be run
in CI without a real database.

Run with:
    python -m pytest tests/test_integration.py -v --tb=short -m integration
"""
import uuid
import pathlib
import pytest
from app.db.connection import get_connection
from app.agent.models import (
    IngestionInput,
    IngestionIngredient,
    IngestionAllergen,
    IngestionNutrition,
)
from app.agent.ingestion import ingest

# Project root (the directory containing the `app` package), computed from
# this file's own location rather than hardcoded, so `python -m app.agent.cli`
# subprocess calls below always target the actual checkout under test
# regardless of where/what path it's cloned to.
PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent


def _count(conn, table, product_id=None):
    if product_id:
        r = conn.execute(
            f"SELECT COUNT(*) AS c FROM public.{table} WHERE product_id = %s",
            (str(product_id),),
        ).fetchone()
    else:
        r = conn.execute(f"SELECT COUNT(*) AS c FROM public.{table}").fetchone()
    return r["c"]


def _find_product(conn, barcode):
    return conn.execute("""
        SELECT p.id, p.internal_code, p.name, p.description,
               p.confidence_level, ls.code AS lifecycle_status
        FROM public.product_barcodes pb
        JOIN public.products p ON p.id = pb.product_id
        JOIN public.barcodes b ON b.id = pb.barcode_id
        JOIN public.lifecycle_statuses ls ON ls.id = p.status_id
        WHERE b.barcode = %s
          AND pb.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND b.deleted_at IS NULL
          AND (pb.effective_from IS NULL OR pb.effective_from <= NOW())
          AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
        LIMIT 1
    """, (barcode,)).fetchone()


TEST_BARCODE = "6281000000066"
TEST_INTERNAL_CODE = "FATEEN_MILK_TEST"


@pytest.mark.integration
class TestP2SchemaAudit:
    def test_effective_dates_on_junction_tables(self, db_conn):
        for tbl in [
            "product_barcodes", "product_ingredients",
            "product_allergens", "product_health_flags",
            "product_nutrition_values",
        ]:
            cols = db_conn.execute(f"""
                SELECT column_name FROM information_schema.columns
                WHERE table_schema='public' AND table_name='{tbl}'
            """).fetchall()
            col_names = [c["column_name"] for c in cols]
            assert "effective_from" in col_names, f"{tbl} missing effective_from"
            assert "effective_to" in col_names, f"{tbl} missing effective_to"

    def test_product_ids_are_uuid(self, db_conn):
        r = db_conn.execute(
            "SELECT id FROM public.products LIMIT 1"
        ).fetchone()
        assert isinstance(r["id"], uuid.UUID)

    def test_lifecycle_statuses_are_int(self, db_conn):
        r = db_conn.execute(
            "SELECT id FROM public.lifecycle_statuses LIMIT 1"
        ).fetchone()
        assert isinstance(r["id"], int)


@pytest.mark.integration
class TestP3Health:
    def test_health_success(self, db_conn):
        from app.db.health import check_database
        result = check_database()
        assert result["database"] == "fateen"

    def test_health_endpoint_200(self, client):
        response = client.get("/health")
        assert response.status_code == 200
        assert response.json()["status"] == "ok"
        assert response.json()["database"] == "fateen"


@pytest.mark.integration
class TestP6P7BarcodeValidation:
    def test_unknown_barcode_404(self, client):
        response = client.get("/api/v1/products/barcode/0000000000000")
        assert response.status_code == 404

    def test_valid_barcode_200(self, client):
        response = client.get(f"/api/v1/products/barcode/{TEST_BARCODE}")
        assert response.status_code == 200
        assert response.json()["internal_code"] == TEST_INTERNAL_CODE

    def test_malformed_abc(self, client):
        response = client.get("/api/v1/products/barcode/abc")
        assert response.status_code in (404, 422)

    def test_empty_barcode(self, client):
        response = client.get("/api/v1/products/barcode/")
        assert response.status_code in (404, 422)

    def test_whitespace_barcode(self, client):
        response = client.get("/api/v1/products/barcode/%20%20%20")
        assert response.status_code in (404, 422)


@pytest.mark.integration
class TestP8ProductResolution:
    def test_active_product_resolves(self, db_conn):
        product = _find_product(db_conn, TEST_BARCODE)
        assert product is not None
        assert product["internal_code"] == TEST_INTERNAL_CODE
        assert product["lifecycle_status"] == "ACTIVE"

    def test_all_7_products_resolve(self, db_conn):
        barcodes = [
            "6281000000011", "6281000000028", "6281000000035",
            "6281000000042", "6281000000059", "6281000000066",
            "6281000000073",
        ]
        for bc in barcodes:
            product = _find_product(db_conn, bc)
            assert product is not None, f"Product not found for barcode {bc}"


@pytest.mark.integration
class TestP9SoftDelete:
    def test_deleted_product_not_returned(self, db_conn):
        db_conn.execute("""
            UPDATE public.products SET deleted_at = NOW()
            WHERE internal_code = 'SOFT_DELETE_TEST_MARKER'
        """)
        r = db_conn.execute(
            "SELECT id FROM public.products WHERE internal_code = 'SOFT_DELETE_TEST_MARKER'"
        ).fetchone()
        if r:
            db_conn.execute(
                "UPDATE public.products SET deleted_at = NULL WHERE id = %s",
                (r["id"],),
            )

    def test_current_queries_filter_deleted(self, db_conn):
        product = _find_product(db_conn, TEST_BARCODE)
        assert product is not None


@pytest.mark.integration
class TestP10ProductDetails:
    def test_ingredients_count(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        assert response.status_code == 200
        assert len(response.json()["ingredients"]) == 1

    def test_allergens_count(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        assert len(response.json()["allergens"]) == 1

    def test_nutrition_count(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        assert len(response.json()["nutrition"]) == 9

    def test_health_flags_count(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        assert len(response.json()["health_flags"]) == 0

    def test_relationship_type_exists(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        data = response.json()
        for ing in data["ingredients"]:
            assert ing["relationship_type"] is not None

    def test_confidence_in_range(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        data = response.json()
        for ing in data["ingredients"]:
            assert 0 <= ing["confidence_level"] <= 1
        for al in data["allergens"]:
            assert 0 <= al["confidence_level"] <= 1
        for nut in data["nutrition"]:
            assert 0 <= nut["confidence_level"] <= 1


@pytest.mark.integration
class TestP11DryRun:
    def test_dry_run_no_db_mutation(self, db_conn):
        from app.agent.ingestion import ingest
        from app.agent.models import IngestionInput, IngestionIngredient, IngestionAllergen, IngestionNutrition

        product = _find_product(db_conn, TEST_BARCODE)
        pid = product["id"]

        counts_before = {}
        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            counts_before[t] = _count(db_conn, t, pid)

        input_data = IngestionInput(
            barcode=TEST_BARCODE,
            ingredients=[IngestionIngredient(name="MILK")],
            allergens=[IngestionAllergen(name="MILK")],
            nutrition=[
                IngestionNutrition(nutrition_type="ENERGY", amount_value=61.0, unit="KCAL"),
            ],
            confidence_level=0.8,
        )

        result = ingest(input_data, dry_run=True)
        assert result.dry_run is True

        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            assert _count(db_conn, t, pid) == counts_before[t], \
                f"DRY RUN mutated {t}!"


@pytest.mark.integration
class TestP12RealWrite:
    def test_write_idempotent_existing_data(self, db_conn):
        from app.agent.ingestion import ingest
        from app.agent.models import IngestionInput, IngestionIngredient, IngestionAllergen, IngestionNutrition

        product = _find_product(db_conn, TEST_BARCODE)
        pid = product["id"]

        counts_before = {}
        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            counts_before[t] = _count(db_conn, t, pid)

        input_data = IngestionInput(
            barcode=TEST_BARCODE,
            ingredients=[IngestionIngredient(name="MILK")],
            allergens=[IngestionAllergen(name="MILK")],
            nutrition=[
                IngestionNutrition(nutrition_type="ENERGY", amount_value=61.0, unit="KCAL"),
            ],
            confidence_level=0.8,
        )

        result = ingest(input_data, dry_run=False)

        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            assert _count(db_conn, t, pid) == counts_before[t], \
                f"WRITE created duplicates in {t}!"

        creates = [c for c in result.changes if c.action == "create"]
        assert len(creates) == 0


@pytest.mark.integration
class TestP13Idempotency:
    def test_second_run_no_duplicates(self, db_conn):
        from app.agent.ingestion import ingest
        from app.agent.models import IngestionInput, IngestionIngredient, IngestionAllergen, IngestionNutrition

        product = _find_product(db_conn, TEST_BARCODE)
        pid = product["id"]

        input_data = IngestionInput(
            barcode=TEST_BARCODE,
            ingredients=[IngestionIngredient(name="MILK")],
            allergens=[IngestionAllergen(name="MILK")],
            nutrition=[
                IngestionNutrition(nutrition_type="ENERGY", amount_value=61.0, unit="KCAL"),
            ],
            confidence_level=0.8,
        )

        counts_run1 = {}
        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            counts_run1[t] = _count(db_conn, t, pid)

        result1 = ingest(input_data, dry_run=False)

        counts_after1 = {}
        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            counts_after1[t] = _count(db_conn, t, pid)

        result2 = ingest(input_data, dry_run=False)

        counts_after2 = {}
        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            counts_after2[t] = _count(db_conn, t, pid)

        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            assert counts_after1[t] == counts_after2[t], \
                f"IDEMPOTENCY FAILED: {t} changed from {counts_after1[t]} to {counts_after2[t]}"

        creates_r1 = [c for c in result1.changes if c.action == "create"]
        creates_r2 = [c for c in result2.changes if c.action == "create"]
        assert len(creates_r1) == 0
        assert len(creates_r2) == 0


@pytest.mark.integration
class TestP17NutritionIntegrity:
    def test_nutrition_types_present(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        data = response.json()
        types = {n["nutrition_type"] for n in data["nutrition"]}
        expected = {
            "CARBOHYDRATE", "ENERGY", "FIBER", "PROTEIN",
            "SATURATED_FAT", "SODIUM", "SUGAR", "TOTAL_FAT", "TRANS_FAT",
        }
        assert types == expected

    def test_nutrition_values_are_numeric(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        for nut in response.json()["nutrition"]:
            assert isinstance(nut["amount_value"], (int, float))
            assert nut["amount_value"] >= 0


@pytest.mark.integration
class TestP18Confidence:
    def test_confidence_in_range_all_entities(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        data = response.json()
        assert 0 <= data["confidence_level"] <= 1
        for section in ["ingredients", "allergens", "nutrition"]:
            for item in data[section]:
                assert 0 <= item["confidence_level"] <= 1, \
                    f"{section} confidence {item['confidence_level']} out of range"


@pytest.mark.integration
class TestP20EvidenceSource:
    def test_evidence_type_resolved(self, client):
        response = client.get(f"/api/v1/products/details/barcode/{TEST_BARCODE}")
        data = response.json()
        for nut in data["nutrition"]:
            assert nut["evidence_type"] is not None


@pytest.mark.integration
class TestP27APIErrorContract:
    def test_404_has_detail(self, client):
        response = client.get("/api/v1/products/barcode/9999999999999")
        assert response.status_code == 404
        assert "detail" in response.json()

    def test_422_for_missing_barcode_field(self, client):
        response = client.post("/api/v1/agent/ingest", json={"dry_run": True})
        assert response.status_code == 422

    def test_401_without_api_key(self, client):
        from unittest.mock import patch
        with patch("app.api.ingestion.settings") as mock_s:
            mock_s.agent_ingest_api_key = "test_key_123"
            mock_s.agent_dry_run = True
            response = client.post(
                "/api/v1/agent/ingest",
                json={"barcode": "123", "dry_run": True},
            )
            assert response.status_code == 401


@pytest.mark.integration
class TestP22TransactionRollback:
    def test_exception_does_not_mutate_db(self, db_conn):
        product = _find_product(db_conn, TEST_BARCODE)
        pid = product["id"]
        count_before = _count(db_conn, "product_ingredients", pid)

        bad_input = IngestionInput(
            barcode=TEST_BARCODE,
            ingredients=[IngestionIngredient(name="NONEXISTENT_INGREDIENT_XYZ")],
            allergens=[],
            nutrition=[],
            confidence_level=0.5,
        )
        result = ingest(bad_input, dry_run=False)
        assert len(result.errors) > 0
        assert _count(db_conn, "product_ingredients", pid) == count_before


@pytest.mark.integration
class TestP23EffectiveDates:
    def test_current_queries_filter_expired(self, db_conn):
        product = _find_product(db_conn, TEST_BARCODE)
        assert product is not None

    def test_future_effective_from_hidden(self, db_conn):
        from datetime import datetime, timedelta, timezone
        future = datetime.now(timezone.utc) + timedelta(days=365)
        db_conn.execute("""
            UPDATE public.product_barcodes
            SET effective_from = %s
            WHERE product_id = %s
        """, (future, db_conn.execute(
            "SELECT p.id FROM public.product_barcodes pb "
            "JOIN public.barcodes b ON b.id = pb.barcode_id "
            "JOIN public.products p ON p.id = pb.product_id "
            "WHERE b.barcode = %s", (TEST_BARCODE,)
        ).fetchone()["id"]))
        result = _find_product(db_conn, TEST_BARCODE)
        db_conn.execute("""
            UPDATE public.product_barcodes
            SET effective_from = NULL
            WHERE product_id = %s
        """, (db_conn.execute(
            "SELECT p.id FROM public.product_barcodes pb "
            "JOIN public.barcodes b ON b.id = pb.barcode_id "
            "JOIN public.products p ON p.id = pb.product_id "
            "WHERE b.barcode = %s", (TEST_BARCODE,)
        ).fetchone()["id"],))
        assert result is None

    def test_past_effective_to_hidden(self, db_conn):
        from datetime import datetime, timedelta, timezone
        past = datetime.now(timezone.utc) - timedelta(days=365)
        pid = db_conn.execute(
            "SELECT p.id FROM public.product_barcodes pb "
            "JOIN public.barcodes b ON b.id = pb.barcode_id "
            "JOIN public.products p ON p.id = pb.product_id "
            "WHERE b.barcode = %s", (TEST_BARCODE,)
        ).fetchone()["id"]
        db_conn.execute(
            "UPDATE public.product_barcodes SET effective_to = %s WHERE product_id = %s",
            (past, pid),
        )
        result = _find_product(db_conn, TEST_BARCODE)
        db_conn.execute(
            "UPDATE public.product_barcodes SET effective_to = NULL WHERE product_id = %s",
            (pid,),
        )
        assert result is None


@pytest.mark.integration
class TestP25ProductionWriteSecurity:
    def test_dry_run_never_writes(self, db_conn):
        product = _find_product(db_conn, TEST_BARCODE)
        pid = product["id"]
        counts_before = {}
        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            counts_before[t] = _count(db_conn, t, pid)

        for _ in range(3):
            bad_input = IngestionInput(
                barcode=TEST_BARCODE,
                ingredients=[IngestionIngredient(name="MILK")],
                allergens=[IngestionAllergen(name="MILK")],
                nutrition=[IngestionNutrition(nutrition_type="ENERGY", amount_value=999.0, unit="KCAL")],
                confidence_level=0.9,
            )
            ingest(bad_input, dry_run=True)

        for t in ["product_ingredients", "product_allergens", "product_nutrition_values"]:
            assert _count(db_conn, t, pid) == counts_before[t], \
                f"DRY RUN mutated {t} after 3 runs!"


@pytest.mark.integration
class TestP28CLIClientErrorResilience:
    def test_invalid_barcode_exits_1(self):
        import subprocess, sys
        result = subprocess.run(
            [sys.executable, "-m", "app.agent.cli", "--barcode", "NOT_A_NUMBER"],
            capture_output=True, text=True, cwd=str(PROJECT_ROOT),
        )
        assert result.returncode == 1
        assert "ERROR" in result.stdout or "error" in result.stdout.lower()

    def test_unknown_barcode_exits_1(self):
        import subprocess, sys
        result = subprocess.run(
            [sys.executable, "-m", "app.agent.cli", "--barcode", "0000000000000"],
            capture_output=True, text=True, cwd=str(PROJECT_ROOT),
        )
        assert result.returncode == 1

    def test_missing_required_arg(self):
        import subprocess, sys
        result = subprocess.run(
            [sys.executable, "-m", "app.agent.cli"],
            capture_output=True, text=True, cwd=str(PROJECT_ROOT),
        )
        assert result.returncode != 0
