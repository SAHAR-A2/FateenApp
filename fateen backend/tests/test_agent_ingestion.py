from unittest.mock import patch, MagicMock, call
from app.agent.ingestion import (
    ingest,
    _compare_ingredients,
    _compare_allergens,
    _compare_nutrition,
)
from app.agent.models import (
    IngestionInput,
    IngestionIngredient,
    IngestionAllergen,
    IngestionNutrition,
)


def _mock_conn():
    conn = MagicMock()
    conn.__enter__ = MagicMock(return_value=conn)
    conn.__exit__ = MagicMock(return_value=False)
    return conn


REFS = {
    "rt_primary": 1,
    "rt_contains": 2,
    "ds_manual": 1,
    "et_inferred": 1,
    "ls_active": 1,
}


def _make_input(**overrides):
    defaults = dict(
        barcode="6281000000066",
        ingredients=[IngestionIngredient(name="MILK")],
        allergens=[IngestionAllergen(name="MILK")],
        nutrition=[
            IngestionNutrition(
                nutrition_type="energy",
                amount_value=61.0,
                unit="kcal",
            )
        ],
        confidence_level=0.8,
    )
    defaults.update(overrides)
    return IngestionInput(**defaults)


class TestSourceEvidenceResolution:
    """Fix 1 (FATEEN Architecture Audit): source_id/evidence_type_id must
    come from IngestionInput.source / .evidence_type resolved against real
    data_sources/evidence_types rows, never hardcoded to a placeholder."""

    @patch("app.agent.ingestion.get_connection")
    def test_unknown_source_code_is_rejected_not_defaulted(self, mock_get_conn):
        conn = _mock_conn()
        mock_get_conn.return_value = conn

        product_row = {"id": 1, "internal_code": "FATEEN_MILK_TEST", "name": "Milk"}
        # relationship_types x4 + lifecycle_statuses x1 all resolve fine,
        # then data_sources lookup returns nothing (unknown code).
        ref_results = [
            product_row,
            {"id": 1}, {"id": 1}, {"id": 1}, {"id": 1}, {"id": 1},
            None,  # data_sources lookup: not found
        ]
        ref_row_counter = 0

        def execute_side_effect(query, params=None):
            nonlocal ref_row_counter
            mock_cursor = MagicMock()
            idx = min(ref_row_counter, len(ref_results) - 1)
            result = ref_results[idx]
            ref_row_counter += 1
            mock_cursor.fetchone.return_value = result
            mock_cursor.fetchall.return_value = []
            return mock_cursor

        conn.execute.side_effect = execute_side_effect

        input_data = _make_input(source="TOTALLY_UNKNOWN_SOURCE")
        result = ingest(input_data, dry_run=True)

        assert any("Unknown data source code" in e for e in result.errors)
        assert not any(
            "FATEEN_TEST" in str(c) for c in conn.execute.call_args_list
        ), "must never silently reference the old placeholder source"
        insert_calls = [c for c in conn.execute.call_args_list if "INSERT" in str(c)]
        assert len(insert_calls) == 0

    @patch("app.agent.ingestion.get_connection")
    def test_known_source_resolves_to_real_id_not_placeholder(self, mock_get_conn):
        conn = _mock_conn()
        mock_get_conn.return_value = conn

        product_row = {"id": 1, "internal_code": "FATEEN_MILK_TEST", "name": "Milk"}
        REAL_SOURCE_ID = "real-source-uuid-999"
        REAL_EVIDENCE_ID = "real-evidence-uuid-888"
        ref_results = [
            product_row,
            {"id": 1}, {"id": 1}, {"id": 1}, {"id": 1}, {"id": 1},  # relationship+lifecycle
            {"id": REAL_SOURCE_ID},      # data_sources lookup
            {"id": REAL_EVIDENCE_ID},    # evidence_types lookup
            [],  # existing ingredients
            [],  # existing allergens
            [],  # existing nutrition
            {"id": "ingredient-uuid-sugar"},  # _resolve_by_name("ingredients", "SUGAR")
        ]
        ref_row_counter = 0

        def execute_side_effect(query, params=None):
            nonlocal ref_row_counter
            mock_cursor = MagicMock()
            idx = min(ref_row_counter, len(ref_results) - 1)
            result = ref_results[idx]
            ref_row_counter += 1
            mock_cursor.fetchone.return_value = (
                result if isinstance(result, dict) else None
            )
            mock_cursor.fetchall.return_value = (
                result if isinstance(result, list) else []
            )
            return mock_cursor

        conn.execute.side_effect = execute_side_effect

        input_data = _make_input(
            source="collector",
            evidence_type="manufacturer_site",
            ingredients=[IngestionIngredient(name="SUGAR")],
        )
        result = ingest(input_data, dry_run=False)

        assert not any(
            "Unknown" in e for e in result.errors
        ), f"should resolve successfully, got errors: {result.errors}"
        insert_calls = [
            c for c in conn.execute.call_args_list if "INSERT INTO public.product_ingredients" in str(c)
        ]
        assert len(insert_calls) == 1
        inserted_params = insert_calls[0].args[1]
        assert REAL_EVIDENCE_ID in inserted_params
        assert REAL_SOURCE_ID in inserted_params


class TestIngestNotFound:
    @patch("app.agent.ingestion.get_connection")
    def test_missing_barcode_returns_error(self, mock_get_conn):
        conn = _mock_conn()
        mock_get_conn.return_value = conn
        conn.execute.return_value.fetchone.return_value = None

        input_data = _make_input(barcode="0000000000000")
        result = ingest(input_data, dry_run=True)

        assert len(result.errors) == 1
        assert "No product found" in result.errors[0]


class TestIngestDryRun:
    @patch("app.agent.ingestion.get_connection")
    def test_dry_run_does_not_write(self, mock_get_conn):
        conn = _mock_conn()
        mock_get_conn.return_value = conn

        product_row = {"id": 1, "internal_code": "FATEEN_MILK_TEST", "name": "Milk"}
        existing_ingredients = [
            {"id": 1, "internal_code": "ING001", "name": "MILK",
             "amount_value": None, "unit": None, "confidence_level": 0.9,
             "ingredient_order": 1}
        ]
        existing_allergens = [
            {"id": 1, "internal_code": "ALL001", "name": "MILK",
             "confidence_level": 0.9}
        ]
        existing_nutrition = [
            {"id": 1, "nutrition_type": "energy", "amount_value": 61.0,
             "unit": "kcal", "confidence_level": 0.85,
             "measurement_basis": None}
        ]

        ref_row_counter = 0
        ref_results = [
            product_row,
            {"id": 1}, {"id": 1}, {"id": 1}, {"id": 1},
            existing_ingredients,
            existing_allergens,
            existing_nutrition,
        ]

        def execute_side_effect(query, params=None):
            nonlocal ref_row_counter
            mock_cursor = MagicMock()
            idx = min(ref_row_counter, len(ref_results) - 1)
            result = ref_results[idx]
            ref_row_counter += 1
            mock_cursor.fetchone.return_value = (
                result if isinstance(result, dict) else None
            )
            mock_cursor.fetchall.return_value = (
                result if isinstance(result, list) else []
            )
            return mock_cursor

        conn.execute.side_effect = execute_side_effect

        input_data = IngestionInput(
            barcode="6281000000066",
            ingredients=[IngestionIngredient(name="MILK")],
            allergens=[IngestionAllergen(name="MILK")],
            nutrition=[
                IngestionNutrition(
                    nutrition_type="energy",
                    amount_value=61.0,
                    unit="kcal",
                )
            ],
            confidence_level=0.8,
        )
        result = ingest(input_data, dry_run=True)

        assert result.dry_run is True
        assert result.product_internal_code == "FATEEN_MILK_TEST"
        assert all(c.action == "no_change" for c in result.changes)
        insert_calls = [
            c for c in conn.execute.call_args_list
            if "INSERT" in str(c)
        ]
        update_calls = [
            c for c in conn.execute.call_args_list
            if "UPDATE" in str(c)
        ]
        assert len(insert_calls) == 0
        assert len(update_calls) == 0


class TestIngestIdempotency:
    @patch("app.agent.ingestion.get_connection")
    def test_same_data_twice_no_duplicates(self, mock_get_conn):
        conn = _mock_conn()
        mock_get_conn.return_value = conn

        product_row = {"id": 1, "internal_code": "FATEEN_MILK_TEST", "name": "Milk"}
        existing_ingredients = [
            {"id": 1, "internal_code": "ING001", "name": "MILK",
             "amount_value": 100.0, "unit": "ml", "confidence_level": 0.9,
             "ingredient_order": 1}
        ]
        existing_allergens = [
            {"id": 1, "internal_code": "ALL001", "name": "MILK",
             "confidence_level": 0.9}
        ]
        existing_nutrition = [
            {"id": 1, "nutrition_type": "energy", "amount_value": 61.0,
             "unit": "kcal", "confidence_level": 0.85,
             "measurement_basis": None}
        ]

        ref_row_counter = 0
        ref_results = [
            product_row,
            {"id": 1}, {"id": 1}, {"id": 1}, {"id": 1},
            existing_ingredients,
            existing_allergens,
            existing_nutrition,
        ]

        def execute_side_effect(query, params=None):
            nonlocal ref_row_counter
            mock_cursor = MagicMock()
            idx = min(ref_row_counter, len(ref_results) - 1)
            result = ref_results[idx]
            ref_row_counter += 1
            mock_cursor.fetchone.return_value = (
                result if isinstance(result, dict) else None
            )
            mock_cursor.fetchall.return_value = (
                result if isinstance(result, list) else []
            )
            return mock_cursor

        conn.execute.side_effect = execute_side_effect

        input_data = _make_input()

        result1 = ingest(input_data, dry_run=False)
        create_count_run1 = sum(
            1 for c in result1.changes if c.action == "create"
        )

        ref_row_counter = 0
        conn.execute.side_effect = execute_side_effect

        result2 = ingest(input_data, dry_run=False)
        create_count_run2 = sum(
            1 for c in result2.changes if c.action == "create"
        )

        assert create_count_run1 == 0
        assert create_count_run2 == 0


class TestCompareIngredients:
    def test_no_change_when_identical(self):
        from app.agent.models import IngestionResult, ProposedChange

        existing = [
            {"id": 1, "internal_code": "ING001", "name": "MILK",
             "amount_value": None, "unit": None,
             "confidence_level": 0.9, "ingredient_order": 1}
        ]
        input_data = _make_input(
            ingredients=[IngestionIngredient(name="MILK")]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_ingredients(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "no_change"

    def test_create_when_new(self):
        from app.agent.models import IngestionResult

        existing = []
        input_data = _make_input(
            ingredients=[IngestionIngredient(name="SUGAR")]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_ingredients(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "create"
        assert result.changes[0].details["name"] == "SUGAR"

    def test_update_when_amount_differs(self):
        from app.agent.models import IngestionResult

        existing = [
            {"id": 1, "internal_code": "ING001", "name": "MILK",
             "amount_value": 100.0, "unit": "ml",
             "confidence_level": 0.9, "ingredient_order": 1}
        ]
        input_data = _make_input(
            ingredients=[
                IngestionIngredient(
                    name="MILK", amount_value=200.0, unit="ml"
                )
            ]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_ingredients(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "update"
        assert result.changes[0].details["new_amount"] == 200.0

    def test_case_insensitive_match(self):
        from app.agent.models import IngestionResult

        existing = [
            {"id": 1, "internal_code": "ING001", "name": "Milk",
             "amount_value": None, "unit": None,
             "confidence_level": 0.5, "ingredient_order": 1}
        ]
        input_data = _make_input(
            ingredients=[IngestionIngredient(name="milk")]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_ingredients(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "no_change"


class TestCompareAllergens:
    def test_no_change_when_exists(self):
        from app.agent.models import IngestionResult

        existing = [
            {"id": 1, "internal_code": "ALL001", "name": "MILK",
             "confidence_level": 0.9}
        ]
        input_data = _make_input(
            allergens=[IngestionAllergen(name="MILK")]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_allergens(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "no_change"

    def test_create_when_new(self):
        from app.agent.models import IngestionResult

        existing = []
        input_data = _make_input(
            allergens=[IngestionAllergen(name="SOY")]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_allergens(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "create"


class TestCompareNutrition:
    def test_no_change_when_identical(self):
        from app.agent.models import IngestionResult

        existing = [
            {"id": 1, "nutrition_type": "energy", "amount_value": 61.0,
             "unit": "kcal", "confidence_level": 0.85,
             "measurement_basis": None}
        ]
        input_data = _make_input(
            nutrition=[
                IngestionNutrition(
                    nutrition_type="energy",
                    amount_value=61.0,
                    unit="kcal",
                )
            ]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_nutrition(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "no_change"

    def test_update_when_amount_differs(self):
        from app.agent.models import IngestionResult

        existing = [
            {"id": 1, "nutrition_type": "energy", "amount_value": 61.0,
             "unit": "kcal", "confidence_level": 0.85,
             "measurement_basis": None}
        ]
        input_data = _make_input(
            nutrition=[
                IngestionNutrition(
                    nutrition_type="energy",
                    amount_value=65.0,
                    unit="kcal",
                )
            ]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_nutrition(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "update"
        assert result.changes[0].details["new_amount"] == 65.0

    def test_create_when_new_type(self):
        from app.agent.models import IngestionResult

        existing = []
        input_data = _make_input(
            nutrition=[
                IngestionNutrition(
                    nutrition_type="protein",
                    amount_value=3.0,
                    unit="g",
                )
            ]
        )
        result = IngestionResult(
            dry_run=True, barcode="6281000000066"
        )

        _compare_nutrition(existing, input_data, REFS, result)

        assert len(result.changes) == 1
        assert result.changes[0].action == "create"
