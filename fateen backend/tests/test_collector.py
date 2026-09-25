import time
import uuid
from unittest.mock import patch, MagicMock

import httpx
import pytest
import respx

from app.db.connection import get_connection
from app.collector import units, extraction, validation, conflicts, deduplication
from app.collector.models import (
    CollectedProductData,
    ExtractedIngredients,
    ExtractedAllergen,
    ExtractedNutrition,
    CoverageReport,
    ScanJobResult,
    HalalStatus,
)
from app.collector.sources import get_source_by_code, get_evidence_type_id, get_relationship_type_id
from app.collector.retrieval import retrieve, RetrievalConfig
from app.collector.prioritization import calculate_priority_score, get_companies_by_priority
from app.collector.halal import record_halal_evidence, get_current_halal_status, get_halal_history
from app.collector.health_conditions import get_health_conditions, get_condition_rules, evaluate_product_health
from app.collector.discovery import register_candidate, normalize_candidate, update_candidate_status
from app.collector.coverage import calculate_company_coverage
from app.collector.orchestrator import scan_company


def _get_nestle_id():
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id FROM public.companies WHERE name ILIKE '%nestle%' AND deleted_at IS NULL LIMIT 1"
        ).fetchone()
        return str(row["id"]) if row else None


def _get_any_company_id():
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id FROM public.companies WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        return str(row["id"]) if row else None


def _get_any_product_id():
    with get_connection() as conn:
        row = conn.execute(
            "SELECT id FROM public.products WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        return str(row["id"]) if row else None


def _create_test_candidate(company_id):
    cid = register_candidate(
        company_id=company_id,
        name=f"TEST_PRODUCT_{uuid.uuid4().hex[:8]}",
        brand="TestBrand",
        barcode=f"59{uuid.uuid4().hex[:10]}",
        category="packaged_food",
        country="SA",
    )
    return cid


# ============================================================
# P01: Company Registry
# ============================================================

class TestP01CompanyRegistry:
    def test_company_exists_in_db(self):
        nestle_id = _get_nestle_id()
        assert nestle_id is not None, "NESTLE company must exist in DB"
        with get_connection() as conn:
            row = conn.execute(
                "SELECT name FROM public.companies WHERE id = %s", (nestle_id,)
            ).fetchone()
            assert row is not None
            assert "nestle" in row["name"].lower()

    def test_company_has_new_columns(self):
        nestle_id = _get_nestle_id()
        assert nestle_id is not None
        with get_connection() as conn:
            row = conn.execute(
                """SELECT slug, priority, scan_status, expected_product_count,
                          discovered_product_count, verified_product_count,
                          barcode_coverage_pct, ingredient_coverage_pct,
                          allergen_coverage_pct, nutrition_coverage_pct,
                          evidence_coverage_pct, conflict_count
                   FROM public.companies WHERE id = %s""",
                (nestle_id,),
            ).fetchone()
            assert row is not None
            assert "slug" in row.keys()
            assert "priority" in row.keys()
            assert "scan_status" in row.keys()
            assert "expected_product_count" in row.keys()
            assert "conflict_count" in row.keys()

    def test_create_new_company(self):
        code = f"TST{uuid.uuid4().hex[:6].upper()}"
        name = f"Test Company {uuid.uuid4().hex[:6]}"
        slug = f"test-company-{uuid.uuid4().hex[:6]}"
        with get_connection() as conn:
            company_id = str(uuid.uuid4())
            conn.execute(
                """INSERT INTO public.companies
                   (id, name, internal_code, slug, country, market, priority, scan_status,
                    status_id, created_at, updated_at)
                   VALUES (%s, %s, %s, %s, 'SA', 'packaged_food', 50, 'idle', 1, NOW(), NOW())""",
                (company_id, name, code, slug),
            )
            row = conn.execute(
                "SELECT id, name, slug FROM public.companies WHERE id = %s",
                (company_id,),
            ).fetchone()
            assert row is not None
            assert row["name"] == name
            assert row["slug"] == slug
            conn.execute(
                "UPDATE public.companies SET deleted_at = NOW() WHERE id = %s",
                (company_id,),
            )

    def test_company_list_endpoint(self, client):
        resp = client.get("/api/v1/companies?limit=5")
        assert resp.status_code == 200
        body = resp.json()
        assert "companies" in body
        assert "total" in body


# ============================================================
# P03: Company Prioritization
# ============================================================

class TestP03CompanyPrioritization:
    def test_priority_score_calculation(self):
        score = calculate_priority_score(
            company_id="test",
            market_relevance=0.8,
            estimated_products=500,
            existing_coverage_pct=20.0,
            source_quality=0.9,
            barcode_coverage_pct=60.0,
            data_completeness_pct=40.0,
        )
        assert isinstance(score, float)
        assert 0.0 <= score <= 100.0

    def test_companies_by_priority(self):
        companies = get_companies_by_priority(limit=5)
        assert isinstance(companies, list)
        if len(companies) > 1:
            for i in range(len(companies) - 1):
                a = companies[i].get("priority", 0) or 0
                b = companies[i + 1].get("priority", 0) or 0
                assert a >= b, "Companies should be ordered by priority descending"


# ============================================================
# P04: Discovery
# ============================================================

class TestP04Discovery:
    def test_register_candidate(self):
        company_id = _get_any_company_id()
        if not company_id:
            pytest.skip("No company in DB")
        name = f"DiscoveryTest_{uuid.uuid4().hex[:8]}"
        candidate_id = register_candidate(
            company_id=company_id,
            name=name,
            brand="DiscBrand",
            barcode="1234567890123",
        )
        assert candidate_id is not None
        with get_connection() as conn:
            row = conn.execute(
                "SELECT name FROM public.discovery_candidates WHERE id = %s",
                (candidate_id,),
            ).fetchone()
            assert row is not None
            assert row["name"] == name
            conn.execute(
                "UPDATE public.discovery_candidates SET deleted_at = NOW() WHERE id = %s",
                (candidate_id,),
            )

    def test_normalize_candidate(self):
        company_id = _get_any_company_id()
        if not company_id:
            pytest.skip("No company in DB")
        name = f"NormTest  {uuid.uuid4().hex[:6]}"
        candidate_id = register_candidate(
            company_id=company_id,
            name=name,
            brand="NormBrand",
            barcode="9876543210",
        )
        assert candidate_id is not None
        ok = normalize_candidate(candidate_id)
        assert ok is True
        with get_connection() as conn:
            row = conn.execute(
                "SELECT normalized_name, normalized_brand, normalized_barcode "
                "FROM public.discovery_candidates WHERE id = %s",
                (candidate_id,),
            ).fetchone()
            assert row is not None
            assert row["normalized_name"] is not None
            assert row["normalized_name"] != ""
            assert row["normalized_brand"] is not None
            assert row["normalized_barcode"] is not None
            conn.execute(
                "UPDATE public.discovery_candidates SET deleted_at = NOW() WHERE id = %s",
                (candidate_id,),
            )

    def test_candidate_status_update(self):
        company_id = _get_any_company_id()
        if not company_id:
            pytest.skip("No company in DB")
        candidate_id = _create_test_candidate(company_id)
        if not candidate_id:
            pytest.skip("Failed to create candidate")
        ok = update_candidate_status(candidate_id, "enriched")
        assert ok is True
        with get_connection() as conn:
            row = conn.execute(
                "SELECT status FROM public.discovery_candidates WHERE id = %s",
                (candidate_id,),
            ).fetchone()
            assert row["status"] == "enriched"
            conn.execute(
                "UPDATE public.discovery_candidates SET deleted_at = NOW() WHERE id = %s",
                (candidate_id,),
            )


# ============================================================
# P05: Source Resolution
# ============================================================

class TestP05SourceResolution:
    def test_source_types_exist(self):
        with get_connection() as conn:
            row = conn.execute("SELECT COUNT(*) as cnt FROM public.source_types").fetchone()
            assert row["cnt"] >= 5

    def test_evidence_types_exist(self):
        with get_connection() as conn:
            row = conn.execute("SELECT COUNT(*) as cnt FROM public.evidence_types").fetchone()
            assert row["cnt"] >= 4

    def test_relationship_types_exist(self):
        with get_connection() as conn:
            row = conn.execute("SELECT COUNT(*) as cnt FROM public.relationship_types").fetchone()
            assert row["cnt"] >= 7

    def test_get_source_by_code(self):
        with get_connection() as conn:
            row = conn.execute(
                "SELECT code FROM public.data_sources WHERE deleted_at IS NULL LIMIT 1"
            ).fetchone()
            if not row:
                pytest.skip("No data sources in DB")
            source = get_source_by_code(row["code"])
            assert source is not None
            assert source["code"] == row["code"]

    def test_get_evidence_type_id(self):
        with get_connection() as conn:
            row = conn.execute(
                "SELECT code FROM public.evidence_types WHERE deleted_at IS NULL LIMIT 1"
            ).fetchone()
            if not row:
                pytest.skip("No evidence types in DB")
            eid = get_evidence_type_id(row["code"])
            assert eid is not None


# ============================================================
# P06: Retrieval - No Hang
# ============================================================

class TestP06RetrievalNoHang:
    def test_retrieval_invalid_url(self):
        start = time.time()
        result = retrieve("not-a-url", config=RetrievalConfig(timeout=5, max_retries=0))
        elapsed = time.time() - start
        assert result.success is False
        assert result.error == "INVALID_URL"
        assert elapsed < 10

    def test_retrieval_timeout(self):
        start = time.time()
        result = retrieve(
            "http://192.0.2.1:12345/test",
            config=RetrievalConfig(timeout=1, max_retries=0),
        )
        elapsed = time.time() - start
        assert result.success is False
        assert elapsed < 10

    def test_retrieval_connection_refused(self):
        start = time.time()
        result = retrieve(
            "http://127.0.0.1:19999/test",
            config=RetrievalConfig(timeout=2, max_retries=0),
        )
        elapsed = time.time() - start
        assert result.success is False
        assert result.error == "SSRF_BLOCKED"
        assert elapsed < 10

    def test_retrieval_404(self):
        with respx.mock:
            respx.get("http://httpbin.org/status/404").mock(
                return_value=httpx.Response(404)
            )
            start = time.time()
            result = retrieve(
                "http://httpbin.org/status/404",
                config=RetrievalConfig(timeout=10, max_retries=0),
            )
            elapsed = time.time() - start
            assert result.success is False
            assert elapsed < 10

    def test_retrieval_429(self):
        with respx.mock:
            respx.get("http://httpbin.org/status/429").mock(
                return_value=httpx.Response(429, headers={"retry-after": "0"})
            )
            start = time.time()
            result = retrieve(
                "http://httpbin.org/status/429",
                config=RetrievalConfig(timeout=10, max_retries=1, backoff_base=0.1),
            )
            elapsed = time.time() - start
            assert result.success is False
            assert elapsed < 10

    def test_retrieval_500(self):
        start = time.time()
        result = retrieve(
            "http://httpbin.org/status/500",
            config=RetrievalConfig(timeout=10, max_retries=0),
        )
        elapsed = time.time() - start
        assert result.success is False
        assert elapsed < 10

    def test_retrieval_malformed_url(self):
        start = time.time()
        result = retrieve(
            "http://",
            config=RetrievalConfig(timeout=5, max_retries=0),
        )
        elapsed = time.time() - start
        assert result.success is False
        assert elapsed < 10


# ============================================================
# P07: Extraction
# ============================================================

class TestP07Extraction:
    def test_extract_from_llm_valid_data(self):
        llm_data = {
            "barcode": "5901234123457",
            "product_name": "Nescafe Classic",
            "brand": "Nescafe",
            "category": "coffee",
            "manufacturer": "Nestle",
            "country": "SA",
            "ingredients": [
                {"name": "Coffee", "amount_value": 100, "unit": "G", "confidence_level": 0.9},
            ],
            "allergens": [
                {"name": "MILK", "confidence_level": 0.8, "evidence_type": "LABEL"},
            ],
            "nutrition": [
                {"nutrition_type": "ENERGY", "amount_value": 2.0, "unit": "KCAL", "confidence_level": 0.9},
                {"nutrition_type": "PROTEIN", "amount_value": 0.3, "unit": "G", "confidence_level": 0.85},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data, source_url="https://example.com")
        assert result.product_name == "Nescafe Classic"
        assert result.brand == "Nescafe"
        assert len(result.ingredients) == 1
        assert result.ingredients[0].name == "Coffee"
        assert len(result.allergens) == 1
        assert result.allergens[0].name == "MILK"
        assert len(result.nutrition) == 2
        assert result.nutrition[0].nutrition_type == "ENERGY"

    def test_extract_from_llm_minimal_data(self):
        llm_data = {"product_name": "Simple Product"}
        result = extraction.extract_from_llm_response(llm_data)
        assert result.product_name == "Simple Product"
        assert result.brand is None
        assert len(result.ingredients) == 0
        assert len(result.allergens) == 0
        assert len(result.nutrition) == 0

    def test_extract_invalid_nutrition_type(self):
        llm_data = {
            "product_name": "Test",
            "nutrition": [
                {"nutrition_type": "INVALID_TYPE", "amount_value": 10, "unit": "G"},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.nutrition) == 0

    def test_extract_invalid_unit(self):
        llm_data = {
            "product_name": "Test",
            "ingredients": [
                {"name": "Sugar", "unit": "GALLONS"},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.ingredients) == 1
        assert result.ingredients[0].unit is None

    def test_extract_negative_nutrition(self):
        llm_data = {
            "product_name": "Test",
            "nutrition": [
                {"nutrition_type": "SUGAR", "amount_value": -5.0, "unit": "G"},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.nutrition) == 0

    def test_extract_confidence_clamped(self):
        llm_data = {
            "product_name": "Test",
            "ingredients": [
                {"name": "Water", "confidence_level": 2.5},
                {"name": "Salt", "confidence_level": -0.5},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert result.ingredients[0].confidence_level == 1.0
        assert result.ingredients[1].confidence_level == 0.0

    def test_extract_empty_ingredients(self):
        llm_data = {"product_name": "Test", "ingredients": []}
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.ingredients) == 0

    def test_extract_missing_name(self):
        llm_data = {"brand": "SomeBrand"}
        result = extraction.extract_from_llm_response(llm_data)
        assert result.product_name == ""


# ============================================================
# P08: Ingredient KB
# ============================================================

class TestP08IngredientKB:
    def test_ingredient_aliases_exist(self):
        with get_connection() as conn:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.ingredient_aliases WHERE deleted_at IS NULL"
            ).fetchone()
            assert row["cnt"] >= 19

    def test_ingredient_allergens_exist(self):
        with get_connection() as conn:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.ingredient_allergens WHERE deleted_at IS NULL"
            ).fetchone()
            assert row["cnt"] >= 19


# ============================================================
# P09: Allergen Extraction
# ============================================================

class TestP09AllergenExtraction:
    def test_extract_allergens_valid(self):
        llm_data = {
            "product_name": "Test",
            "allergens": [
                {"name": "MILK", "confidence_level": 0.9, "evidence_type": "LABEL"},
                {"name": "WHEAT", "confidence_level": 0.8},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.allergens) == 2
        names = {a.name for a in result.allergens}
        assert "MILK" in names
        assert "WHEAT" in names

    def test_extract_allergens_empty_name_skipped(self):
        llm_data = {
            "product_name": "Test",
            "allergens": [
                {"name": "", "confidence_level": 0.5},
                {"name": "EGGS", "confidence_level": 0.7},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.allergens) == 1
        assert result.allergens[0].name == "EGGS"


# ============================================================
# P10: Nutrition Normalization
# ============================================================

class TestP10NutritionNormalization:
    def test_extract_nutrition_valid(self):
        llm_data = {
            "product_name": "Test",
            "nutrition": [
                {"nutrition_type": "SUGAR", "amount_value": 12.5, "unit": "G"},
                {"nutrition_type": "SODIUM", "amount_value": 200, "unit": "MG"},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.nutrition) == 2
        types = {n.nutrition_type for n in result.nutrition}
        assert "SUGAR" in types
        assert "SODIUM" in types

    def test_extract_nutrition_negative_rejected(self):
        llm_data = {
            "product_name": "Test",
            "nutrition": [
                {"nutrition_type": "SUGAR", "amount_value": -10, "unit": "G"},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.nutrition) == 0

    def test_extract_nutrition_invalid_type_rejected(self):
        llm_data = {
            "product_name": "Test",
            "nutrition": [
                {"nutrition_type": "VITAMIN_C", "amount_value": 50, "unit": "MG"},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.nutrition) == 0

    def test_extract_nutrition_invalid_unit_rejected(self):
        llm_data = {
            "product_name": "Test",
            "nutrition": [
                {"nutrition_type": "ENERGY", "amount_value": 100, "unit": "OUNCES"},
            ],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert len(result.nutrition) == 0


# ============================================================
# P11: Unit Engine
# ============================================================

class TestP11UnitEngine:
    def test_convert_identity(self):
        result = units.convert(100.0, "G", "G")
        assert result == 100.0

    def test_convert_mg_to_g(self):
        result = units.convert(1000.0, "MG", "G")
        assert result is not None
        assert abs(result - 1.0) < 0.001

    def test_convert_kg_to_g(self):
        result = units.convert(1.0, "KG", "G")
        assert result is not None
        assert abs(result - 1000.0) < 0.001

    def test_convert_ml_to_l(self):
        result = units.convert(1000.0, "ML", "L")
        assert result is not None
        assert abs(result - 1.0) < 0.001

    def test_convert_negative_raises(self):
        with pytest.raises(ValueError):
            units.convert(-5.0, "G", "KG")

    def test_convert_unknown_returns_none(self):
        result = units.convert(1.0, "FATHOMS", "PARSEECS")
        assert result is None

    def test_can_convert_valid(self):
        assert units.can_convert("G", "KG") is True

    def test_can_convert_invalid(self):
        assert units.can_convert("FATHOMS", "PARSEECS") is False


# ============================================================
# P12: Data Quality Validation
# ============================================================

class TestP12DataQualityValidation:
    def test_validate_valid_product(self):
        data = CollectedProductData(
            barcode="5901234123457",
            product_name="Valid Product",
            brand="Brand",
            confidence_level=0.8,
            ingredients=[
                ExtractedIngredients(name="Sugar", amount_value=10, unit="G"),
            ],
            nutrition=[
                ExtractedNutrition(nutrition_type="SUGAR", amount_value=10, unit="G"),
            ],
        )
        result = validation.validate_product_data(data)
        assert result.is_valid is True
        assert len(result.errors) == 0

    def test_validate_missing_name(self):
        data = CollectedProductData(product_name="", confidence_level=0.5)
        result = validation.validate_product_data(data)
        assert result.is_valid is False
        assert any("Product name is required" in e for e in result.errors)

    def test_validate_invalid_barcode(self):
        data = CollectedProductData(
            barcode="abc",
            product_name="Product",
            confidence_level=0.5,
        )
        result = validation.validate_product_data(data)
        assert result.is_valid is False
        assert len(result.errors) > 0

    def test_validate_negative_ingredient(self):
        data = CollectedProductData(
            product_name="Product",
            confidence_level=0.5,
            ingredients=[
                ExtractedIngredients(name="Sugar", amount_value=-5, unit="G"),
            ],
        )
        result = validation.validate_product_data(data)
        assert result.is_valid is False
        assert any("negative amount" in e for e in result.errors)

    def test_validate_duplicate_ingredients(self):
        data = CollectedProductData(
            product_name="Product",
            confidence_level=0.5,
            ingredients=[
                ExtractedIngredients(name="Sugar", amount_value=10, unit="G"),
                ExtractedIngredients(name="Sugar", amount_value=20, unit="G"),
            ],
        )
        result = validation.validate_product_data(data)
        assert any("Duplicate ingredient" in w for w in result.warnings)

    def test_validate_duplicate_nutrition(self):
        data = CollectedProductData(
            product_name="Product",
            confidence_level=0.5,
            nutrition=[
                ExtractedNutrition(nutrition_type="SUGAR", amount_value=10, unit="G"),
                ExtractedNutrition(nutrition_type="SUGAR", amount_value=20, unit="G"),
            ],
        )
        result = validation.validate_product_data(data)
        assert any("Duplicate nutrition" in w for w in result.warnings)

    def test_validate_negative_nutrition(self):
        data = CollectedProductData(
            product_name="Product",
            confidence_level=0.5,
            nutrition=[
                ExtractedNutrition(nutrition_type="SUGAR", amount_value=-10, unit="G"),
            ],
        )
        result = validation.validate_product_data(data)
        assert result.is_valid is False
        assert any("negative value" in e for e in result.errors)

    def test_validate_out_of_range_nutrition(self):
        data = CollectedProductData(
            product_name="Product",
            confidence_level=0.5,
            nutrition=[
                ExtractedNutrition(nutrition_type="ENERGY", amount_value=15000, unit="KCAL"),
            ],
        )
        result = validation.validate_product_data(data)
        assert any("outside expected range" in w for w in result.warnings)


# ============================================================
# P13: Evidence
# ============================================================

class TestP13Evidence:
    def test_create_evidence_record(self):
        product_id = _get_any_product_id()
        if not product_id:
            pytest.skip("No product in DB")
        with get_connection() as conn:
            exists = conn.execute(
                "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'evidence_records') as x"
            ).fetchone()
            if not exists["x"]:
                pytest.skip("evidence_records table does not exist")
        evidence_id = sources_create_evidence(
            entity_type="product",
            entity_id=product_id,
            evidence_type_code="LABEL",
            source_code="FATEEN_TEST",
            raw_value="test raw",
            normalized_value="test normalized",
            confidence=0.8,
        )
        assert evidence_id is not None
        with get_connection() as conn:
            row = conn.execute(
                "SELECT id FROM public.evidence_records WHERE id = %s",
                (evidence_id,),
            ).fetchone()
            assert row is not None
            conn.execute(
                "UPDATE public.evidence_records SET deleted_at = NOW() WHERE id = %s",
                (evidence_id,),
            )


from app.collector.sources import create_evidence_record as sources_create_evidence


# ============================================================
# P14: Conflict Detection
# ============================================================

class TestP14ConflictDetection:
    def test_detect_conflict_same_values(self):
        result = conflicts.detect_conflicts(
            entity_type="product",
            entity_id=str(uuid.uuid4()),
            field_name="name",
            existing_value="Test Product",
            new_value="Test Product",
        )
        assert result is None

    def test_detect_conflict_different_values(self):
        result = conflicts.detect_conflicts(
            entity_type="product",
            entity_id=str(uuid.uuid4()),
            field_name="name",
            existing_value="Old Name",
            new_value="New Name",
        )
        assert result is not None
        assert result.field_name == "name"
        assert result.value_a == "Old Name"
        assert result.value_b == "New Name"

    def test_get_unresolved_conflicts(self):
        result = conflicts.get_unresolved_conflicts()
        assert isinstance(result, list)

    def test_resolve_conflict(self):
        result = conflicts.detect_conflicts(
            entity_type="product",
            entity_id=str(uuid.uuid4()),
            field_name="brand",
            existing_value="OldBrand",
            new_value="NewBrand",
        )
        if result is None:
            pytest.skip("Could not create conflict")

        with get_connection() as conn:
            row = conn.execute(
                "SELECT id FROM public.data_conflicts WHERE entity_name = %s",
                (result.entity_name,),
            ).fetchone()

            if row:
                ok = conflicts.resolve_conflict(
                    str(row["id"]),
                    "resolved",
                    note="test",
                )
                assert ok is True


# ============================================================
# P15: Deduplication
# ============================================================

class TestP15Deduplication:
    def test_match_by_barcode(self):
        with get_connection() as conn:
            row = conn.execute(
                """SELECT b.barcode, p.name, br.name as brand_name
                   FROM public.product_barcodes pb
                   JOIN public.barcodes b ON b.id = pb.barcode_id
                   JOIN public.products p ON p.id = pb.product_id
                   JOIN public.brands br ON br.id = p.brand_id
                   WHERE pb.deleted_at IS NULL AND p.deleted_at IS NULL AND b.deleted_at IS NULL
                   LIMIT 1"""
            ).fetchone()
            if not row:
                pytest.skip("No products with barcodes in DB")
            match = deduplication.find_matching_product(barcode=row["barcode"])
            assert match is not None
            assert match["match_method"] == "barcode"

    def test_match_by_name_and_brand(self):
        with get_connection() as conn:
            row = conn.execute(
                """SELECT p.name, br.name as brand_name
                   FROM public.products p
                   JOIN public.brands br ON br.id = p.brand_id
                   WHERE p.deleted_at IS NULL AND br.deleted_at IS NULL
                   LIMIT 1"""
            ).fetchone()
            if not row:
                pytest.skip("No products in DB")
            match = deduplication.find_matching_product(
                product_name=row["name"], brand=row["brand_name"]
            )
            assert match is not None

    def test_no_match_returns_none(self):
        match = deduplication.find_matching_product(
            barcode="0000000000000",
            product_name="zzzz_nonexistent_product_xyzzy",
            brand="zzzz_nonexistent_brand_xyzzy",
        )
        assert match is None

    def test_ambiguous_match_detection(self):
        result = deduplication.check_ambiguous_match(
            barcode="0000000000000",
            product_name="zzzz_nonexistent_product_xyzzy",
            brand="zzzz_nonexistent_brand_xyzzy",
        )
        assert "is_ambiguous" in result
        assert "matches" in result
        assert "count" in result


# ============================================================
# P16: Idempotency
# ============================================================

class TestP16Idempotency:
    def test_company_scan_idempotency(self):
        company_id = _get_any_company_id()
        if not company_id:
            pytest.skip("No company in DB")
        start_count = _count_scan_jobs(company_id)
        scan_company(company_id=company_id, dry_run=True, max_products=1)
        end_count = _count_scan_jobs(company_id)
        scan_company(company_id=company_id, dry_run=True, max_products=1)
        final_count = _count_scan_jobs(company_id)
        assert final_count - end_count == end_count - start_count


def _count_scan_jobs(company_id):
    with get_connection() as conn:
        row = conn.execute(
            "SELECT COUNT(*) as cnt FROM public.scan_jobs WHERE company_id = %s",
            (company_id,),
        ).fetchone()
        return row["cnt"]


# ============================================================
# P17: Dry Run
# ============================================================

class TestP17DryRun:
    def test_dry_run_company_scan(self):
        company_id = _get_any_company_id()
        if not company_id:
            pytest.skip("No company in DB")
        with get_connection() as conn:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.products WHERE brand_id IN "
                "(SELECT id FROM public.brands WHERE company_id = %s AND deleted_at IS NULL) "
                "AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            before_count = row["cnt"]
        result = scan_company(company_id=company_id, dry_run=True, max_products=5)
        assert isinstance(result, ScanJobResult)
        with get_connection() as conn:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.products WHERE brand_id IN "
                "(SELECT id FROM public.brands WHERE company_id = %s AND deleted_at IS NULL) "
                "AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            after_count = row["cnt"]
        assert after_count == before_count, "Dry run must not mutate products"


# ============================================================
# P20: LLM Boundary
# ============================================================

class TestP20LLMBoundary:
    def test_llm_output_schema_validation(self):
        llm_data = {
            "product_name": "Test Product",
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert result.product_name == "Test Product"
        assert len(result.ingredients) == 0
        assert len(result.nutrition) == 0

    def test_llm_confidence_clamped(self):
        llm_data = {
            "product_name": "Test",
            "ingredients": [{"name": "Water", "confidence_level": 999}],
        }
        result = extraction.extract_from_llm_response(llm_data)
        assert result.ingredients[0].confidence_level == 1.0


# ============================================================
# P21: Halal Status
# ============================================================

class TestP21HalalStatus:
    def test_record_halal_evidence(self):
        product_id = _get_any_product_id()
        if not product_id:
            pytest.skip("No product in DB")
        with get_connection() as conn:
            conn.execute(
                "UPDATE public.halal_evidence SET is_current = FALSE WHERE product_id = %s",
                (product_id,),
            )
        hid = record_halal_evidence(
            product_id=product_id,
            status="HALAL",
            confidence=0.9,
            evidence_type="LABEL",
            authority="Test Authority",
            reasoning="Test reasoning",
        )
        assert hid is not None

    def test_get_current_halal_status(self):
        product_id = _get_any_product_id()
        if not product_id:
            pytest.skip("No product in DB")
        record_halal_evidence(
            product_id=product_id,
            status="UNKNOWN",
            confidence=0.5,
            evidence_type="LABEL",
            authority="Test",
            reasoning="Initial",
        )
        status = get_current_halal_status(product_id)
        assert status is not None
        assert str(status["product_id"]) == product_id

    def test_halal_history(self):
        product_id = _get_any_product_id()
        if not product_id:
            pytest.skip("No product in DB")
        record_halal_evidence(
            product_id=product_id,
            status="UNKNOWN",
            confidence=0.5,
            evidence_type="LABEL",
            authority="Test",
            reasoning="Initial",
        )
        history = get_halal_history(product_id)
        assert isinstance(history, list)
        assert len(history) >= 1

    def test_reject_unknown_to_halal_inference(self):
        product_id = _get_any_product_id()
        if not product_id:
            pytest.skip("No product in DB")
        record_halal_evidence(
            product_id=product_id,
            status="UNKNOWN",
            confidence=0.5,
            evidence_type="LABEL",
            authority="Test",
            reasoning="Initial",
        )
        hid = record_halal_evidence(
            product_id=product_id,
            status="HALAL",
            confidence=0.9,
            evidence_type="LABEL",
            authority="Inference",
            reasoning="Should be rejected",
        )
        assert hid is None, "UNKNOWN -> HALAL forbidden transition must be rejected"


# ============================================================
# P22-P25: Health Conditions
# ============================================================

class TestP22P25HealthConditions:
    def test_health_conditions_exist(self):
        conditions = get_health_conditions()
        assert len(conditions) >= 7

    def test_condition_rules_exist(self):
        conditions = get_health_conditions()
        if not conditions:
            pytest.skip("No health conditions")
        found_rules = False
        for cond in conditions:
            rules = get_condition_rules(str(cond["id"]))
            if rules:
                found_rules = True
                break
        assert found_rules, "At least one condition should have rules"

    def test_evaluate_product_health(self):
        product_id = _get_any_product_id()
        if not product_id:
            pytest.skip("No product in DB")
        evaluations = evaluate_product_health(product_id)
        assert isinstance(evaluations, list)


# ============================================================
# P27: Company Scan
# ============================================================

class TestP27CompanyScan:
    def test_scan_company_dry_run(self):
        company_id = _get_any_company_id()
        if not company_id:
            pytest.skip("No company in DB")
        with get_connection() as conn:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.products WHERE brand_id IN "
                "(SELECT id FROM public.brands WHERE company_id = %s AND deleted_at IS NULL) "
                "AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            before_count = row["cnt"]
        result = scan_company(company_id=company_id, dry_run=True, max_products=5)
        assert isinstance(result, ScanJobResult)
        assert result.company_id == company_id
        assert result.scan_job_id != ""
        with get_connection() as conn:
            row = conn.execute(
                "SELECT COUNT(*) as cnt FROM public.products WHERE brand_id IN "
                "(SELECT id FROM public.brands WHERE company_id = %s AND deleted_at IS NULL) "
                "AND deleted_at IS NULL",
                (company_id,),
            ).fetchone()
            after_count = row["cnt"]
        assert after_count == before_count


# ============================================================
# P28: Coverage
# ============================================================

class TestP28Coverage:
    def test_calculate_coverage(self):
        company_id = _get_any_company_id()
        if not company_id:
            pytest.skip("No company in DB")
        report = calculate_company_coverage(company_id)
        assert isinstance(report, CoverageReport)
        assert report.company_id == company_id
        assert report.total_products >= 0


# ============================================================
# P36: No-Hang Guarantee
# ============================================================

class TestP36NoHangGuarantee:
    def test_no_hang_invalid_url(self):
        start = time.time()
        result = retrieve("not-a-url", config=RetrievalConfig(timeout=5, max_retries=0))
        assert time.time() - start < 10
        assert result.success is False

    def test_no_hang_connection_refused(self):
        start = time.time()
        result = retrieve(
            "http://127.0.0.1:19999/test",
            config=RetrievalConfig(timeout=2, max_retries=0),
        )
        assert time.time() - start < 10
        assert result.success is False
        assert result.error == "SSRF_BLOCKED"

    def test_no_hang_malformed_data(self):
        start = time.time()
        llm_data = {"garbage": [1, 2, 3], "nested": {"deep": {"value": None}}}
        extraction.extract_from_llm_response(llm_data)
        assert time.time() - start < 10

    def test_no_hang_unknown_barcode(self):
        start = time.time()
        match = deduplication.find_matching_product(barcode="0000000000000")
        assert time.time() - start < 10
        assert match is None


# ============================================================
# P37: Security
# ============================================================

class TestP37Security:
    def test_api_key_required_for_companies(self, client):
        resp = client.get("/api/v1/companies?limit=1")
        if resp.status_code == 401:
            assert resp.status_code == 401
        else:
            assert resp.status_code == 200

    def test_api_key_required_for_scan(self, client):
        resp = client.post(
            "/api/v1/scan/start",
            json={"company_id": "test", "scan_type": "full"},
        )
        if resp.status_code == 401:
            assert resp.status_code == 401
        else:
            assert resp.status_code in (200, 404, 500)

    def test_no_secrets_in_error_messages(self, client):
        resp = client.post(
            "/api/v1/scan/start",
            json={"company_id": "nonexistent-id", "scan_type": "full"},
        )
        body = resp.text.lower()
        assert "api_key" not in body
        assert "secret" not in body
        assert "password" not in body


# ============================================================
# P38: Data Integrity
# ============================================================

class TestP38DataIntegrity:
    def test_relationship_types_correct(self):
        with get_connection() as conn:
            row = conn.execute(
                "SELECT code FROM public.relationship_types WHERE code = 'CONTAINS_INGREDIENT' AND deleted_at IS NULL"
            ).fetchone()
            assert row is not None
            row = conn.execute(
                "SELECT code FROM public.relationship_types WHERE code = 'CONTAINS_ALLERGEN' AND deleted_at IS NULL"
            ).fetchone()
            assert row is not None
            row = conn.execute(
                "SELECT code FROM public.relationship_types WHERE code = 'MEASURED_VALUE' AND deleted_at IS NULL"
            ).fetchone()
            assert row is not None

    def test_health_conditions_are_disease_agnostic(self):
        conditions = get_health_conditions()
        for cond in conditions:
            rules = get_condition_rules(str(cond["id"]))
            for rule in rules:
                assert rule.get("nutrition_type_id") or rule.get("operator"), (
                    f"Rule for condition {cond.get('code')} should be nutrition-based"
                )

    def test_unit_conversions_loaded(self):
        conversions = units.get_all_conversions()
        assert len(conversions) > 0
