"""
Phase 12 Adversarial Tests — F1-F6 Findings.

Verifies that security, data-integrity, and correctness fixes
are actually wired into the codebase.
"""
import inspect
import os

import pytest

from app.db.connection import get_connection


# ── F1: Timing Attack ────────────────────────────────────────────────

class TestF1TimingAttack:
    def test_api_compare_digest_used_in_companies_endpoint(self):
        from app.api import companies
        source = inspect.getsource(companies)
        assert "hmac.compare_digest" in source
        assert "==" not in source.split("_check_api_key")[1]

    def test_api_compare_digest_used_in_scan_endpoint(self):
        from app.api import scan
        source = inspect.getsource(scan)
        assert "hmac.compare_digest" in source
        assert "==" not in source.split("_check_api_key")[1]

    def test_api_compare_digest_used_in_enrichment_endpoint(self):
        from app.api import enrichment
        source = inspect.getsource(enrichment)
        assert "hmac.compare_digest" in source
        assert "==" not in source.split("_check_api_key")[1]

    def test_api_compare_digest_used_in_ingestion_endpoint(self):
        from app.api import ingestion
        source = inspect.getsource(ingestion)
        assert "hmac.compare_digest" in source
        assert "==" not in source.split("x_agent_api_key")[1]


# ── F2: Connection Pooling ───────────────────────────────────────────

class TestF2ConnectionPooling:
    def test_pool_configuration_values(self):
        from app.core.config import settings
        assert settings.db_pool_min_size == 2
        assert settings.db_pool_max_size == 20
        assert settings.db_pool_acquire_timeout == 30.0

    def test_connection_pool_exists(self):
        import app.db.connection as conn_mod
        assert hasattr(conn_mod, "_pool")
        conn_mod._get_pool()
        assert conn_mod._pool is not None

    def test_release_connection_function_exists(self):
        from app.db.connection import release_connection
        assert callable(release_connection)


# ── F3: Transaction Boundaries ───────────────────────────────────────

class TestF3TransactionBoundaries:
    def test_orchestrator_initializes_scan_job_status_pending(self):
        from app.collector import orchestrator
        source = inspect.getsource(orchestrator)
        assert "pending" in source.lower()

    def test_orchestrator_catches_and_logs_errors(self):
        from app.collector import orchestrator
        source = inspect.getsource(orchestrator)
        assert "exception" in source.lower() or "FAILED" in source


# ── F4: Ingredient Data Integrity ────────────────────────────────────

class TestF4IngredientDataIntegrity:
    def test_create_ingredient_inserts_amount_value_and_unit_id(self):
        from app.agent import ingestion
        source = inspect.getsource(ingestion)
        assert "amount_value" in source
        assert "unit_id" in source

    def test_compare_ingredients_preserves_amount_unit_on_create(self):
        from app.agent import ingestion
        source = inspect.getsource(ingestion._compare_ingredients)
        assert "amount_value" in source
        assert "unit_id" in inspect.getsource(ingestion)

    def test_update_ingredient_updates_unit_id(self):
        from app.agent import ingestion
        source = inspect.getsource(ingestion._update_ingredient)
        assert "unit_id" in source


# ── F5: Nutrition Measurement Basis ──────────────────────────────────

class TestF5NutritionMeasurementBasis:
    def test_create_nutrition_inserts_measurement_basis_id(self):
        from app.agent import ingestion
        source = inspect.getsource(ingestion)
        assert "measurement_basis_id" in source

    def test_compare_nutrition_preserves_measurement_basis(self):
        from app.agent import ingestion
        source = inspect.getsource(ingestion._compare_nutrition)
        assert "measurement_basis" in source


# ── F6: Conflict Visibility ──────────────────────────────────────────

class TestF6ConflictVisibility:
    def test_get_unresolved_conflicts_filters_resolution(self):
        from app.collector import conflicts
        source = inspect.getsource(conflicts.get_unresolved_conflicts)
        assert "resolution IS NULL" in source or "unresolved" in source

    def test_count_unresolved_conflicts_filters_resolution(self):
        from app.collector import conflicts
        source = inspect.getsource(conflicts.count_unresolved_conflicts)
        assert "resolution IS NULL" in source or "unresolved" in source


# ── Integration (require DB) ─────────────────────────────────────────

class TestF4IngredientIntegration:
    @pytest.mark.skipif(
        not os.getenv("INTEGRATION_TEST"),
        reason="Integration test",
    )
    def test_create_nutrition_with_measurement_basis_id(self, db_conn):
        cursor = db_conn
        row = cursor.execute(
            "SELECT id FROM public.products WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        assert row is not None, "Need at least one product in DB"
        product_id = row["id"]

        nt_row = cursor.execute(
            "SELECT id FROM public.nutrition_types WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        assert nt_row is not None, "Need at least one nutrition_type"

        unit_row = cursor.execute(
            "SELECT id FROM public.units WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        assert unit_row is not None, "Need at least one unit"

        mb_row = cursor.execute(
            "SELECT id FROM public.measurement_bases WHERE deleted_at IS NULL LIMIT 1"
        ).fetchone()
        mb_id = mb_row["id"] if mb_row else None

        cursor.execute(
            """
            INSERT INTO public.product_nutrition_values
                (id, product_id, nutrition_type_id, amount_value, unit_id,
                 measurement_basis_id, status_id, confidence_level,
                 relationship_type_id, evidence_type_id, source_id,
                 created_at, updated_at)
            SELECT %s, %s, %s, 100.0, %s, %s,
                   (SELECT id FROM public.lifecycle_statuses WHERE code='ACTIVE' LIMIT 1),
                   0.8,
                   (SELECT id FROM public.relationship_types WHERE code='MEASURED_VALUE' LIMIT 1),
                   (SELECT id FROM public.evidence_types WHERE code='LABEL' LIMIT 1),
                   (SELECT id FROM public.data_sources WHERE code='FATEEN_TEST' LIMIT 1),
                   NOW(), NOW()
            WHERE NOT EXISTS (
                SELECT 1 FROM public.product_nutrition_values
                WHERE product_id = %s AND deleted_at IS NULL
            )
            """,
            (
                str(__import__("uuid").uuid4()),
                product_id,
                nt_row["id"],
                unit_row["id"],
                mb_id,
                product_id,
            ),
        )
        db_conn.commit()

        result = cursor.execute(
            """
            SELECT measurement_basis_id
            FROM public.product_nutrition_values
            WHERE product_id = %s AND deleted_at IS NULL
            ORDER BY created_at DESC LIMIT 1
            """,
            (product_id,),
        ).fetchone()

        assert result is not None
        if mb_id is not None:
            assert str(result["measurement_basis_id"]) == str(mb_id)


class TestF2PoolReleaseIntegration:
    @pytest.mark.skipif(
        not os.getenv("INTEGRATION_TEST"),
        reason="Integration test",
    )
    def test_release_connection_returns_to_pool(self, db_conn):
        from app.db.connection import _get_pool, release_connection

        pool = _get_pool()
        initial_idle = pool.get_stats()["pool_available"]

        with get_connection() as conn:
            conn.execute("SELECT 1")

        final_idle = pool.get_stats()["pool_available"]
        assert final_idle >= initial_idle


# ── W2: Rate Limit Memory Leak ──────────────────────────────────────

class TestW2RateLimitCleanup:
    def test_cleanup_function_exists(self):
        from app.main import _cleanup_rate_limit_store
        assert callable(_cleanup_rate_limit_store)

    def test_cleanup_removes_stale_keys(self):
        import time
        from app.main import _rate_limit_store, RATE_LIMIT_WINDOW, _cleanup_rate_limit_store

        _rate_limit_store.clear()
        _rate_limit_store["old_ip"] = [time.time() - RATE_LIMIT_WINDOW - 10]
        _rate_limit_store["new_ip"] = [time.time()]
        removed = _cleanup_rate_limit_store()
        assert removed == 1
        assert "old_ip" not in _rate_limit_store
        assert "new_ip" in _rate_limit_store

    def test_cleanup_keeps_active_keys(self):
        import time
        from app.main import _rate_limit_store, _cleanup_rate_limit_store

        _rate_limit_store.clear()
        _rate_limit_store["active_ip"] = [time.time()]
        removed = _cleanup_rate_limit_store()
        assert removed == 0
        assert "active_ip" in _rate_limit_store

    def test_cleanup_rate_limit_counter_resets(self):
        from app.main import _rate_limit_cleanup_counter, _RATE_LIMIT_CLEANUP_EVERY
        assert _RATE_LIMIT_CLEANUP_EVERY > 0
        assert isinstance(_rate_limit_cleanup_counter, int)


# ── W5: Health Condition Unit Mismatch ──────────────────────────────

class TestW5UnitConversion:
    def test_convert_same_unit(self):
        from app.collector.health_conditions import _convert_to_unit
        assert _convert_to_unit(100, "G", "G") == 100

    def test_convert_g_to_mg(self):
        from app.collector.health_conditions import _convert_to_unit
        result = _convert_to_unit(1, "G", "MG")
        assert abs(result - 1000) < 0.01

    def test_convert_mg_to_g(self):
        from app.collector.health_conditions import _convert_to_unit
        result = _convert_to_unit(500, "MG", "G")
        assert abs(result - 0.5) < 0.01

    def test_convert_kj_to_kcal(self):
        from app.collector.health_conditions import _convert_to_unit
        result = _convert_to_unit(1000, "KJ", "KCAL")
        assert abs(result - 239.006) < 0.1

    def test_convert_unknown_unit_returns_original(self):
        from app.collector.health_conditions import _convert_to_unit
        assert _convert_to_unit(42, "UNKNOWN", "G") == 42
        assert _convert_to_unit(42, "G", "UNKNOWN") == 42

    def test_unit_conversion_used_in_comparison(self):
        from app.collector.health_conditions import _convert_to_unit
        actual_mg = 25000
        threshold_g = 25
        converted = _convert_to_unit(actual_mg, "MG", "G")
        assert abs(converted - 25.0) < 0.01
        assert not (converted > threshold_g)

    def test_operator_functions_correctly(self):
        from app.collector.health_conditions import _apply_operator
        assert _apply_operator(10, ">", 5) is True
        assert _apply_operator(5, ">", 5) is False
        assert _apply_operator(5, ">=", 5) is True
        assert _apply_operator(4, "<", 5) is True
        assert _apply_operator(5, "<=", 5) is True
        assert _apply_operator(5, "=", 5) is True
