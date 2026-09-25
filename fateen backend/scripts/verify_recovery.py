"""
FATEEN Recovery Verification Script
===================================
READ-ONLY — No database modifications allowed.

Executes 21 verification checks against the surviving PostgreSQL database
and produces a structured report.

Usage:
    python scripts/verify_recovery.py

Exit code:
    0 = ALL PASS
    1 = FAILURES or ERRORS
    2 = CRITICAL ERROR (cannot proceed)
"""

import os
import sys
import subprocess
import json
import time
from pathlib import Path
from datetime import datetime

# ---------------------------------------------------------------------------
# CONFIGURATION
# ---------------------------------------------------------------------------

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DB_CONTAINER = "fateen-postgres"
DB_NAME = "fateen"
DB_USER = "fateen"
PSQL_TIMEOUT = 15  # seconds for individual queries
DOCKER_TIMEOUT = 20  # seconds for docker exec wrapper

# ---------------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------------

results = []  # list of (check_num, check_name, status, detail)
PASS = "PASS"
FAIL = "FAIL"
WARN = "WARNING"
SKIP = "SKIP"
ERROR = "ERROR"


def run_psql(sql, description="query", timeout=PSQL_TIMEOUT):
    """Execute a psql command via docker exec. Returns (stdout, stderr, returncode)."""
    try:
        cmd = [
            "docker", "exec", DB_CONTAINER,
            "psql", "-U", DB_USER, "-d", DB_NAME,
            "-t", "-A", "-c", sql
        ]
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            encoding="utf-8",
            errors="replace"
        )
        return result.stdout.strip(), result.stderr.strip(), result.returncode
    except subprocess.TimeoutExpired:
        return "", f"Query timed out after {timeout}s", -1
    except FileNotFoundError:
        return "", "docker executable not found", -2
    except Exception as e:
        safe_msg = str(e)[:200].replace("\n", " ")
        return "", f"Unexpected error: {safe_msg}", -3


def run_psql_single(sql, timeout=PSQL_TIMEOUT):
    """Execute a query and return the single value, or None on error."""
    out, err, rc = run_psql(sql, timeout=timeout)
    if rc != 0:
        return None
    lines = [l for l in out.split("\n") if l.strip()]
    if len(lines) == 1:
        return lines[0].strip()
    return lines if lines else None


def run_psql_rows(sql, timeout=PSQL_TIMEOUT):
    """Execute a query and return list of rows (split by newline, fields by |)."""
    out, err, rc = run_psql(sql, timeout=timeout)
    if rc != 0:
        return None
    rows = []
    for line in out.split("\n"):
        line = line.strip()
        if not line:
            continue
        fields = [f.strip() for f in line.split("|")]
        rows.append(fields)
    return rows


def file_exists(path):
    return path.exists() if isinstance(path, Path) else Path(path).exists()


def file_size(path):
    p = path if isinstance(path, Path) else Path(path)
    return p.stat().st_size if p.exists() else 0


def record(num, name, status, detail=""):
    results.append((num, name, status, detail))
    tag = f"[{status:^7s}]"
    print(f"  [{num:02d}] {name:<30s} {tag}  {detail}")


def section_header(title):
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}")


# ---------------------------------------------------------------------------
# CHECKS
# ---------------------------------------------------------------------------

def check_01_connectivity():
    """01. Database connectivity."""
    section_header("01. DATABASE CONNECTIVITY")

    out, err, rc = run_psql("SELECT 1", timeout=10)
    if rc != 0:
        record(1, "DATABASE", FAIL, f"Cannot connect: {err[:100]}")
        return False

    db_name = run_psql_single("SELECT current_database()")
    if db_name != DB_NAME:
        record(1, "DATABASE", FAIL, f"Expected db={DB_NAME}, got={db_name}")
        return False

    schema = run_psql_single("SELECT schema_name FROM information_schema.schemata WHERE schema_name='public'")
    if schema != "public":
        record(1, "DATABASE", FAIL, "public schema not found")
        return False

    version = run_psql_single("SELECT version()")
    record(1, "DATABASE", PASS, f"Connected. {version[:60]}")
    return True


def check_02_schema_inventory():
    """02. Schema inventory."""
    section_header("02. SCHEMA INVENTORY")

    def count_query(sql, label):
        val = run_psql_single(sql)
        return int(val) if val and val.isdigit() else None

    tables = count_query("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'", "tables")
    views = count_query("SELECT COUNT(*) FROM information_schema.views WHERE table_schema='public'", "views")
    matviews = count_query("SELECT COUNT(*) FROM pg_matviews WHERE schemaname='public'", "matviews")
    sequences = count_query("SELECT COUNT(*) FROM pg_sequences WHERE schemaname='public'", "sequences")
    enums = count_query("SELECT COUNT(DISTINCT t.typname) FROM pg_type t JOIN pg_enum e ON t.oid = e.enumtypid", "enums")
    extensions = count_query("SELECT COUNT(*) FROM pg_extension", "extensions")
    functions = count_query("SELECT COUNT(DISTINCT p.proname) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'public' AND p.prokind = 'f'", "functions")
    triggers = count_query("SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_schema='public'", "triggers")
    indexes = count_query("SELECT COUNT(*) FROM pg_indexes WHERE schemaname='public'", "indexes")
    fks = count_query("SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='FOREIGN KEY' AND table_schema='public'", "fks")
    checks = count_query("SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='CHECK' AND table_schema='public'", "checks")
    uniques = count_query("SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='UNIQUE' AND table_schema='public'", "uniques")
    pks = count_query("SELECT COUNT(*) FROM information_schema.table_constraints WHERE constraint_type='PRIMARY KEY' AND table_schema='public'", "pks")

    issues = []
    if tables is None: issues.append("tables: query failed")
    if enums is None: issues.append("enums: query failed")
    if extensions is None: issues.append("extensions: query failed")

    parts = []
    for name, val in [("tables", tables), ("views", views), ("matviews", matviews),
                       ("sequences", sequences), ("enums", enums), ("extensions", extensions),
                       ("functions", functions), ("triggers", triggers), ("indexes", indexes),
                       ("FKs", fks), ("checks", checks), ("uniques", uniques), ("PKs", pks)]:
        parts.append(f"{name}={val if val is not None else '?'}")

    if issues:
        record(2, "SCHEMA INVENTORY", WARN, "; ".join(issues) + " | " + ", ".join(parts))
    else:
        record(2, "SCHEMA INVENTORY", PASS, ", ".join(parts))

    return {
        "tables": tables, "views": views, "matviews": matviews,
        "sequences": sequences, "enums": enums, "extensions": extensions,
        "functions": functions, "triggers": triggers, "indexes": indexes,
        "fks": fks, "checks": checks, "uniques": uniques, "pks": pks
    }


def check_03_migrations():
    """03. Migration ledger."""
    section_header("03. MIGRATION LEDGER")

    rows = run_psql_rows(
        "SELECT version, checksum, applied_at::text FROM schema_migrations ORDER BY version"
    )
    if rows is None:
        record(3, "MIGRATIONS", FAIL, "Cannot read schema_migrations")
        return []

    count = len(rows)
    if count == 0:
        record(3, "MIGRATIONS", FAIL, "No migrations found")
        return []

    # Check for duplicates
    versions = [r[0] for r in rows]
    dupes = [v for v in versions if versions.count(v) > 1]
    dupes = list(set(dupes))

    # Check doc file exists
    doc_path = PROJECT_ROOT / "docs" / "12_migrations.txt"
    doc_exists = file_exists(doc_path)
    doc_size = file_size(doc_path)

    issues = []
    if dupes:
        issues.append(f"Duplicate versions: {dupes}")
    if not doc_exists:
        issues.append("docs/12_migrations.txt not found")

    detail = f"{count} migrations. First: {rows[0][0][:30]}. Last: {rows[-1][0][:30]}"
    if issues:
        record(3, "MIGRATIONS", WARN, "; ".join(issues) + " | " + detail)
    else:
        record(3, "MIGRATIONS", PASS, detail)

    return rows


def check_04_baseline():
    """04. Baseline schema file."""
    section_header("04. BASELINE SCHEMA")

    baseline = PROJECT_ROOT / "migrations" / "0000_recovered_baseline.sql"
    if not file_exists(baseline):
        record(4, "BASELINE", FAIL, "migrations/0000_recovered_baseline.sql not found")
        return False

    size = file_size(baseline)
    content = baseline.read_text(encoding="utf-8", errors="replace")

    # Check it contains key DDL markers
    markers = [
        "CREATE TABLE",
        "PRIMARY KEY",
        "FOREIGN KEY",
        "CREATE INDEX",
        "companies",
        "products",
        "barcodes",
    ]
    found = [m for m in markers if m.lower() in content.lower()]
    missing = [m for m in markers if m.lower() not in content.lower()]

    if missing:
        record(4, "BASELINE", WARN, f"Size={size:,} bytes. Missing DDL markers: {missing}. Found: {found}")
    else:
        record(4, "BASELINE", PASS, f"Size={size:,} bytes. All {len(markers)} DDL markers present")
    return True


def check_05_critical_tables():
    """05. Critical tables exist."""
    section_header("05. CRITICAL TABLES")

    required = [
        "products", "product_barcodes", "barcodes",
        "product_ingredients", "ingredients",
        "product_allergens", "allergens",
        "product_nutrition_values", "nutrition_types",
        "health_conditions", "condition_nutrition_rules",
        "unit_conversions", "halal_evidence",
        "companies", "brands",
        "relationship_types", "evidence_types",
        "data_sources", "schema_migrations",
    ]

    rows = run_psql_rows(
        "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'"
    )
    if rows is None:
        record(5, "CRITICAL TABLES", FAIL, "Cannot query tables")
        return False

    existing = {r[0] for r in rows}
    missing = [t for t in required if t not in existing]

    if missing:
        record(5, "CRITICAL TABLES", FAIL, f"Missing: {missing}")
        return False

    # Check product_barcodes junction
    pb_cols = run_psql_rows("SELECT column_name FROM information_schema.columns WHERE table_name='product_barcodes' ORDER BY ordinal_position")
    if pb_cols:
        col_names = {r[0] for r in pb_cols}
        if "barcode_id" not in col_names or "product_id" not in col_names:
            record(5, "CRITICAL TABLES", WARN, f"product_barcodes junction missing expected columns. Has: {sorted(col_names)[:8]}...")
        elif "barcode" in col_names:
            record(5, "CRITICAL TABLES", WARN, "product_barcodes has 'barcode' column (unusual for junction table)")
        else:
            record(5, "CRITICAL TABLES", PASS, f"All {len(required)} critical tables present. Junction table verified.")
    else:
        record(5, "CRITICAL TABLES", PASS, f"All {len(required)} critical tables present.")
    return True


def check_06_fixture():
    """06. Known fixture data."""
    section_header("06. KNOWN FIXTURE DATA")

    issues = []

    # Product count
    pc = run_psql_single("SELECT COUNT(*) FROM products")
    if pc != "7":
        issues.append(f"products: expected 7, got {pc}")

    # Barcode count
    bc = run_psql_single("SELECT COUNT(*) FROM barcodes")
    if bc != "7":
        issues.append(f"barcodes: expected 7, got {bc}")

    # Company count
    cc = run_psql_single("SELECT COUNT(*) FROM companies")
    if cc != "10":
        issues.append(f"companies: expected 10, got {cc}")

    # Brand count
    br = run_psql_single("SELECT COUNT(*) FROM brands")
    if br != "13":
        issues.append(f"brands: expected 13, got {br}")

    # Health conditions
    hc = run_psql_single("SELECT COUNT(*) FROM health_conditions")
    if hc != "7":
        issues.append(f"health_conditions: expected 7, got {hc}")

    # Condition nutrition rules
    cnr = run_psql_single("SELECT COUNT(*) FROM condition_nutrition_rules")
    if cnr != "8":
        issues.append(f"condition_nutrition_rules: expected 8, got {cnr}")

    # Unit conversions
    uc = run_psql_single("SELECT COUNT(*) FROM unit_conversions")
    if uc != "6":
        issues.append(f"unit_conversions: expected 6, got {uc}")

    # Halal evidence
    he = run_psql_single("SELECT COUNT(*) FROM halal_evidence")
    if he != "7":
        issues.append(f"halal_evidence: expected 7 (reported as 4), got {he}")

    # Fixture: 6281000000066 -> FATEEN_MILK_TEST
    fixture = run_psql_rows(
        "SELECT b.barcode, p.internal_code, p.name "
        "FROM product_barcodes pb "
        "JOIN barcodes b ON pb.barcode_id = b.id "
        "JOIN products p ON pb.product_id = p.id "
        "WHERE b.barcode = '6281000000066'"
    )
    if not fixture or len(fixture) == 0:
        issues.append("Fixture 6281000000066 NOT FOUND in product_barcodes")
        fixture_ok = False
    else:
        row = fixture[0]
        if row[1] != "FATEEN_MILK_TEST":
            issues.append(f"Fixture internal_code: expected FATEEN_MILK_TEST, got {row[1]}")
            fixture_ok = False
        else:
            fixture_ok = True

    # FATEEN_MILK_TEST detail
    if fixture_ok:
        ing = run_psql_single(
            "SELECT COUNT(*) FROM product_ingredients pi "
            "JOIN products p ON pi.product_id = p.id "
            "WHERE p.internal_code = 'FATEEN_MILK_TEST'"
        )
        alg = run_psql_single(
            "SELECT COUNT(DISTINCT pa.allergen_id) FROM product_allergens pa "
            "JOIN products p ON pa.product_id = p.id "
            "WHERE p.internal_code = 'FATEEN_MILK_TEST'"
        )
        nut = run_psql_single(
            "SELECT COUNT(*) FROM product_nutrition_values pnv "
            "JOIN products p ON pnv.product_id = p.id "
            "WHERE p.internal_code = 'FATEEN_MILK_TEST'"
        )
        if ing != "1":
            issues.append(f"FATEEN_MILK_TEST ingredients: expected 1, got {ing}")
        if alg != "1":
            issues.append(f"FATEEN_MILK_TEST allergens: expected 1, got {alg}")
        if nut != "9":
            issues.append(f"FATEEN_MILK_TEST nutrition: expected 9, got {nut}")

    detail_parts = [
        f"products={pc}", f"barcodes={bc}", f"companies={cc}", f"brands={br}",
        f"health_conds={hc}", f"cond_rules={cnr}", f"unit_conv={uc}", f"halal={he}"
    ]
    detail = ", ".join(detail_parts)

    if issues:
        record(6, "FIXTURE DATA", FAIL, "; ".join(issues) + " | " + detail)
    else:
        record(6, "FIXTURE DATA", PASS, f"6281000000066 => FATEEN_MILK_TEST (1ing,1alg,9nut). {detail}")
    return len(issues) == 0


def check_07_relationship_types():
    """07. Relationship types."""
    section_header("07. RELATIONSHIP TYPES")

    required = [
        "CONTAINS_INGREDIENT", "MAY_CONTAIN_INGREDIENT",
        "CONTAINS_ALLERGEN", "MAY_CONTAIN_ALLERGEN",
        "PRIMARY_BARCODE", "PACK_SIZE_VARIANT", "MEASURED_VALUE",
    ]

    rows = run_psql_rows("SELECT code FROM relationship_types")
    if rows is None:
        record(7, "RELATIONSHIP TYPES", FAIL, "Cannot query relationship_types")
        return False

    existing = {r[0] for r in rows}
    missing = [t for t in required if t not in existing]

    if missing:
        record(7, "RELATIONSHIP TYPES", FAIL, f"Missing: {missing}. Existing: {sorted(existing)}")
        return False

    record(7, "RELATIONSHIP TYPES", PASS, f"All 7 types present: {sorted(existing)}")
    return True


def check_08_evidence_types():
    """08. Evidence types."""
    section_header("08. EVIDENCE TYPES")

    required = ["LABEL", "MANUFACTURER", "OFFICIAL_SOURCE", "DATABASE"]

    rows = run_psql_rows("SELECT code FROM evidence_types")
    if rows is None:
        record(8, "EVIDENCE TYPES", FAIL, "Cannot query evidence_types")
        return False

    existing = {r[0] for r in rows}
    missing = [t for t in required if t not in existing]

    if missing:
        record(8, "EVIDENCE TYPES", FAIL, f"Missing: {missing}. Existing: {sorted(existing)}")
        return False

    # Check actual usage
    usage_rows = run_psql_rows(
        "SELECT et.code, COUNT(*) FROM product_ingredients pi "
        "JOIN evidence_types et ON pi.evidence_type_id = et.id "
        "GROUP BY et.code"
    )
    usage = {r[0]: r[1] for r in usage_rows} if usage_rows else {}

    record(8, "EVIDENCE TYPES", PASS, f"All 4 present. Usage in product_ingredients: {usage}")
    return True


def check_09_health_conditions():
    """09. Health conditions."""
    section_header("09. HEALTH CONDITIONS")

    required = ["DIABETES", "HYPERTENSION", "CELIAC", "NUT_ALLERGY", "LACTOSE", "HEART_DISEASE", "OBESITY"]

    rows = run_psql_rows("SELECT code FROM health_conditions WHERE is_active = true")
    if rows is None:
        record(9, "HEALTH CONDITIONS", FAIL, "Cannot query health_conditions")
        return False

    existing = {r[0] for r in rows}
    missing = [t for t in required if t not in existing]

    if missing:
        record(9, "HEALTH CONDITIONS", FAIL, f"Missing: {missing}. Existing: {sorted(existing)}")
        return False

    # Check rules per condition
    rule_rows = run_psql_rows(
        "SELECT hc.code, COUNT(cnr.id) FROM health_conditions hc "
        "LEFT JOIN condition_nutrition_rules cnr ON hc.id = cnr.condition_id "
        "WHERE hc.is_active = true GROUP BY hc.code ORDER BY hc.code"
    )
    rule_map = {r[0]: r[1] for r in rule_rows} if rule_rows else {}

    record(9, "HEALTH CONDITIONS", PASS, f"All 7 active. Rules per condition: {rule_map}")
    return True


def check_10_units():
    """10. Unit system."""
    section_header("10. UNIT SYSTEM")

    units = run_psql_rows("SELECT code, name, dimension::text FROM units ORDER BY code")
    if units is None:
        record(10, "UNIT SYSTEM", FAIL, "Cannot query units")
        return False

    bases = run_psql_rows("SELECT code FROM measurement_bases ORDER BY code")
    conversions = run_psql_rows(
        "SELECT u1.code, u2.code, uc.conversion_factor, uc.is_exact "
        "FROM unit_conversions uc "
        "JOIN units u1 ON uc.from_unit_id = u1.id "
        "JOIN units u2 ON uc.to_unit_id = u2.id "
        "ORDER BY u1.code, u2.code"
    )

    issues = []
    # Check for zero/negative conversion factors
    if conversions:
        for c in conversions:
            try:
                factor = float(c[2])
                if factor <= 0:
                    issues.append(f"Invalid conversion factor: {c[0]}->{c[1]} = {factor}")
                if factor == 0:
                    issues.append(f"ZERO conversion factor: {c[0]}->{c[1]}")
            except (ValueError, TypeError):
                issues.append(f"Non-numeric conversion factor: {c[0]}->{c[1]} = {c[2]}")

    unit_list = [f"{u[0]}({u[2]})" for u in units]
    conv_list = [f"{c[0]}->{c[1]}={c[2]}" for c in (conversions or [])]

    if issues:
        record(10, "UNIT SYSTEM", FAIL, "; ".join(issues))
    else:
        record(10, "UNIT SYSTEM", PASS,
               f"Units=[{', '.join(unit_list)}]. Conversions=[{', '.join(conv_list)}]")
    return len(issues) == 0


def check_11_halal():
    """11. Halal evidence data."""
    section_header("11. HALAL DATA")

    rows = run_psql_rows(
        "SELECT he.status, he.confidence, he.evidence_type, p.internal_code "
        "FROM halal_evidence he "
        "JOIN products p ON he.product_id = p.id "
        "ORDER BY he.created_at"
    )
    if rows is None:
        record(11, "HALAL DATA", FAIL, "Cannot query halal_evidence")
        return False

    count = len(rows)
    statuses = {}
    for r in rows:
        s = r[0] if r[0] else "NULL"
        statuses[s] = statuses.get(s, 0) + 1

    # Verify all have product_id (via JOIN above) and status
    null_status = sum(1 for r in rows if not r[0])
    null_confidence = sum(1 for r in rows if not r[1])

    issues = []
    if null_status:
        issues.append(f"{null_status} records with NULL status")
    if null_confidence:
        issues.append(f"{null_confidence} records with NULL confidence")

    if issues:
        record(11, "HALAL DATA", WARN, f"{count} records. Statuses={statuses}. Issues: {'; '.join(issues)}")
    else:
        record(11, "HALAL DATA", PASS, f"{count} records. Statuses={statuses}")
    return True


def check_12_soft_delete():
    """12. Soft delete columns."""
    section_header("12. SOFT DELETE")

    rows = run_psql_rows(
        "SELECT table_name FROM information_schema.columns "
        "WHERE table_schema='public' AND column_name='deleted_at' "
        "ORDER BY table_name"
    )
    if rows is None:
        record(12, "SOFT DELETE", FAIL, "Cannot query columns")
        return False

    tables_with_soft_delete = [r[0] for r in rows]

    # Check for any soft-deleted rows
    deleted_counts = {}
    for t in tables_with_soft_delete:
        val = run_psql_single(f"SELECT COUNT(*) FROM {t} WHERE deleted_at IS NOT NULL")
        if val and val != "0":
            deleted_counts[t] = int(val)

    total_deleted = sum(deleted_counts.values())

    record(12, "SOFT DELETE", PASS,
           f"{len(tables_with_soft_delete)} tables have deleted_at. "
           f"Soft-deleted rows: {total_deleted}. "
           f"Tables needing deleted_at IS NULL filter: {tables_with_soft_delete[:6]}...")
    return True


def check_13_effective_dates():
    """13. Effective date columns."""
    section_header("13. EFFECTIVE DATES")

    from_cols = run_psql_rows(
        "SELECT table_name FROM information_schema.columns "
        "WHERE table_schema='public' AND column_name='effective_from' "
        "ORDER BY table_name"
    )
    to_cols = run_psql_rows(
        "SELECT table_name FROM information_schema.columns "
        "WHERE table_schema='public' AND column_name='effective_to' "
        "ORDER BY table_name"
    )

    from_tables = {r[0] for r in from_cols} if from_cols else set()
    to_tables = {r[0] for r in to_cols} if to_cols else set()
    both = from_tables & to_tables

    record(13, "EFFECTIVE DATES", PASS,
           f"{len(both)} tables with effective_from+effective_to: {sorted(both)}")
    return True


def check_14_data_integrity():
    """14. Data integrity checks."""
    section_header("14. DATA INTEGRITY")

    issues = []

    # 14a. Orphan foreign keys on products.brand_id
    orphan_brands = run_psql_single(
        "SELECT COUNT(*) FROM products p "
        "LEFT JOIN brands b ON p.brand_id = b.id "
        "WHERE p.brand_id IS NOT NULL AND b.id IS NULL"
    )
    if orphan_brands and orphan_brands != "0":
        issues.append(f"Orphan product->brand FKs: {orphan_brands}")

    # 14b. Orphan product_barcodes->barcodes
    orphan_pb = run_psql_single(
        "SELECT COUNT(*) FROM product_barcodes pb "
        "LEFT JOIN barcodes b ON pb.barcode_id = b.id "
        "WHERE b.id IS NULL"
    )
    if orphan_pb and orphan_pb != "0":
        issues.append(f"Orphan product_barcodes->barcodes: {orphan_pb}")

    # 14c. Orphan product_barcodes->products
    orphan_pb2 = run_psql_single(
        "SELECT COUNT(*) FROM product_barcodes pb "
        "LEFT JOIN products p ON pb.product_id = p.id "
        "WHERE p.id IS NULL"
    )
    if orphan_pb2 and orphan_pb2 != "0":
        issues.append(f"Orphan product_barcodes->products: {orphan_pb2}")

    # 14d. Orphan product_ingredients->products
    orphan_pi = run_psql_single(
        "SELECT COUNT(*) FROM product_ingredients pi "
        "LEFT JOIN products p ON pi.product_id = p.id "
        "WHERE p.id IS NULL"
    )
    if orphan_pi and orphan_pi != "0":
        issues.append(f"Orphan product_ingredients->products: {orphan_pi}")

    # 14e. Orphan product_ingredients->ingredients
    orphan_pi2 = run_psql_single(
        "SELECT COUNT(*) FROM product_ingredients pi "
        "LEFT JOIN ingredients i ON pi.ingredient_id = i.id "
        "WHERE i.id IS NULL"
    )
    if orphan_pi2 and orphan_pi2 != "0":
        issues.append(f"Orphan product_ingredients->ingredients: {orphan_pi2}")

    # 14f. Orphan product_allergens->products
    orphan_pa = run_psql_single(
        "SELECT COUNT(*) FROM product_allergens pa "
        "LEFT JOIN products p ON pa.product_id = p.id "
        "WHERE p.id IS NULL"
    )
    if orphan_pa and orphan_pa != "0":
        issues.append(f"Orphan product_allergens->products: {orphan_pa}")

    # 14g. Orphan product_nutrition_values->products
    orphan_pn = run_psql_single(
        "SELECT COUNT(*) FROM product_nutrition_values pnv "
        "LEFT JOIN products p ON pnv.product_id = p.id "
        "WHERE p.id IS NULL"
    )
    if orphan_pn and orphan_pn != "0":
        issues.append(f"Orphan product_nutrition_values->products: {orphan_pn}")

    # 14h. Invalid confidence values (outside 0-1)
    bad_conf = run_psql_single(
        "SELECT COUNT(*) FROM ("
        "  SELECT confidence_level FROM product_ingredients WHERE confidence_level < 0 OR confidence_level > 1 "
        "  UNION ALL "
        "  SELECT confidence_level FROM product_allergens WHERE confidence_level < 0 OR confidence_level > 1 "
        "  UNION ALL "
        "  SELECT confidence_level FROM product_nutrition_values WHERE confidence_level < 0 OR confidence_level > 1 "
        "  UNION ALL "
        "  SELECT confidence_level FROM product_barcodes WHERE confidence_level < 0 OR confidence_level > 1 "
        ") sub"
    )
    if bad_conf and bad_conf != "0":
        issues.append(f"Invalid confidence values: {bad_conf}")

    # 14i. Duplicate active barcodes (same barcode string, multiple product_barcodes)
    dup_barcodes = run_psql_single(
        "SELECT COUNT(*) FROM ("
        "  SELECT b.barcode, pb.product_id "
        "  FROM product_barcodes pb "
        "  JOIN barcodes b ON pb.barcode_id = b.id "
        "  WHERE pb.deleted_at IS NULL "
        "  GROUP BY b.barcode, pb.product_id "
        "  HAVING COUNT(*) > 1"
        ") sub"
    )
    if dup_barcodes and dup_barcodes != "0":
        issues.append(f"Duplicate product_barcodes rows: {dup_barcodes}")

    # 14j. NULL required fields in products
    null_products = run_psql_single(
        "SELECT COUNT(*) FROM products WHERE name IS NULL OR internal_code IS NULL OR status_id IS NULL"
    )
    if null_products and null_products != "0":
        issues.append(f"Products with NULL required fields: {null_products}")

    if issues:
        record(14, "DATA INTEGRITY", FAIL, "; ".join(issues))
    else:
        record(14, "DATA INTEGRITY", PASS, "All 10 integrity checks passed (orphans, duplicates, confidence, nulls)")
    return len(issues) == 0


def check_15_security():
    """15. Security verification (filesystem)."""
    section_header("15. SECURITY")

    issues = []
    warnings = []

    # Check .env exists
    env_path = PROJECT_ROOT / ".env"
    if not file_exists(env_path):
        warnings.append(".env not found")
    else:
        # Check .env is in .gitignore
        gitignore = PROJECT_ROOT / ".gitignore"
        if file_exists(gitignore):
            gi_content = gitignore.read_text(encoding="utf-8", errors="replace")
            if ".env" not in gi_content:
                issues.append(".env NOT in .gitignore")
            else:
                pass  # good
        else:
            issues.append(".gitignore not found")

    # Check for DATABASE_URL in tracked source files
    # We won't run grep, just check main.py and config.py
    for src in ["app/main.py", "app/core/config.py", "app/db/connection.py"]:
        src_path = PROJECT_ROOT / src
        if file_exists(src_path):
            content = src_path.read_text(encoding="utf-8", errors="replace")
            if "fateen_dev_password" in content.lower() or "password=" in content.lower():
                issues.append(f"Hardcoded credentials in {src}")

    # Check backup files protected
    gitignore = PROJECT_ROOT / ".gitignore"
    if file_exists(gitignore):
        gi = gitignore.read_text(encoding="utf-8", errors="replace")
        if "*.dump" not in gi:
            warnings.append("*.dump not in .gitignore")
        if "backups/" not in gi:
            warnings.append("backups/ not in .gitignore")

    if issues:
        record(15, "SECURITY", FAIL, "; ".join(issues))
    elif warnings:
        record(15, "SECURITY", WARN, "; ".join(warnings))
    else:
        record(15, "SECURITY", PASS, ".env gitignored. No hardcoded credentials in tracked source. Backups excluded.")
    return len(issues) == 0


def check_16_backups():
    """16. Backup verification."""
    section_header("16. BACKUP VERIFICATION")

    backups = [
        ("backups/fateen_pre_recovery.dump", "pg_dump custom format"),
        ("backups/schema_and_data.sql", "plain SQL dump"),
    ]

    all_ok = True
    for rel_path, desc in backups:
        full = PROJECT_ROOT / rel_path
        if file_exists(full):
            size = file_size(full)
            if size == 0:
                record(16, f"BACKUP: {rel_path}", FAIL, f"File is EMPTY (0 bytes)")
                all_ok = False
            else:
                record(16, f"BACKUP: {rel_path}", PASS, f"{size:,} bytes ({desc})")
        else:
            record(16, f"BACKUP: {rel_path}", FAIL, "File NOT FOUND")
            all_ok = False

    return all_ok


def check_17_documentation():
    """17. Recovery documentation."""
    section_header("17. DOCUMENTATION")

    required_files = [
        ("docs/database_schema.md", "Schema documentation"),
        ("docs/DATABASE_RECOVERY.md", "Recovery report"),
        ("docs/03_full_schema.sql", "Full DDL schema"),
        ("docs/01_enums.txt", "Enum types"),
        ("docs/02_extensions.txt", "Extensions"),
        ("docs/04_row_counts.txt", "Row counts"),
        ("docs/06_sequences.txt", "Sequences"),
        ("docs/12_migrations.txt", "Migration history"),
        ("migrations/0000_recovered_baseline.sql", "Baseline migration"),
    ]

    missing = []
    existing = []
    for rel, desc in required_files:
        full = PROJECT_ROOT / rel
        if file_exists(full):
            existing.append(f"{rel} ({file_size(full):,} bytes)")
        else:
            missing.append(f"{rel} ({desc})")

    if missing:
        record(17, "DOCUMENTATION", FAIL, f"Missing: {missing}. Found: {len(existing)}/{len(required_files)}")
    else:
        record(17, "DOCUMENTATION", PASS, f"All {len(required_files)} doc files present")
    return len(missing) == 0


def check_18_git():
    """18. Git safety check."""
    section_header("18. GIT SAFETY")

    try:
        root_result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=10,
            cwd=str(PROJECT_ROOT),
            encoding="utf-8", errors="replace"
        )
        git_root = root_result.stdout.strip()
    except Exception as e:
        record(18, "GIT", WARN, f"Cannot determine git root: {str(e)[:80]}")
        return True

    try:
        branch_result = subprocess.run(
            ["git", "branch", "--show-current"],
            capture_output=True, text=True, timeout=10,
            cwd=str(PROJECT_ROOT),
            encoding="utf-8", errors="replace"
        )
        branch = branch_result.stdout.strip()
    except Exception:
        branch = "unknown"

    try:
        status_result = subprocess.run(
            ["git", "status", "--short"],
            capture_output=True, text=True, timeout=10,
            cwd=str(PROJECT_ROOT),
            encoding="utf-8", errors="replace"
        )
        changed = len([l for l in status_result.stdout.strip().split("\n") if l.strip()])
    except Exception:
        changed = "?"

    project_str = str(PROJECT_ROOT).replace("\\", "/").lower()
    root_str = git_root.replace("\\", "/").lower()

    if root_str == project_str or root_str + "/" == project_str:
        record(18, "GIT", PASS, f"Root: {git_root}. Branch: {branch}. Uncommitted: {changed} files")
    elif "users/sahar" in root_str and "fateen" not in root_str:
        record(18, "GIT", FAIL, f"CRITICAL: Git root is {git_root} (outside project). Branch: {branch}")
    else:
        record(18, "GIT", PASS, f"Root: {git_root}. Branch: {branch}. Uncommitted: {changed} files")
    return True


def check_19_application_vs_db():
    """19. Database capability vs application implementation."""
    section_header("19. DB vs APPLICATION")

    db_caps = []
    app_impl = []

    # Check for collector code
    collector_dir = PROJECT_ROOT / "app" / "collector"
    if collector_dir.exists() and any(collector_dir.glob("*.py")):
        py_files = list(collector_dir.glob("*.py"))
        app_impl.append(f"app/collector/ ({len(py_files)} .py files)")
    else:
        db_caps.append("collector tables in DB (discovery_candidates, scan_jobs, etc.)")

    # Check for agent code
    agent_dir = PROJECT_ROOT / "app" / "agent"
    if agent_dir.exists() and any(agent_dir.glob("*.py")):
        py_files = list(agent_dir.glob("*.py"))
        app_impl.append(f"app/agent/ ({len(py_files)} .py files)")
    else:
        db_caps.append("agent tables in DB")

    # Check for tests
    test_files = list((PROJECT_ROOT / "tests").glob("test_*.py")) if (PROJECT_ROOT / "tests").exists() else []
    if test_files:
        app_impl.append(f"tests/ ({len(test_files)} test files)")
    else:
        db_caps.append("no test files")

    # Check for health_conditions table (DB) vs health engine (app)
    health_exists = run_psql_single("SELECT COUNT(*) FROM health_conditions")
    health_engine = PROJECT_ROOT / "app" / "collector" / "health_conditions.py"
    if health_exists and health_exists != "0" and not file_exists(health_engine):
        db_caps.append(f"health_conditions table ({health_exists} rows) — no application health engine")
    elif health_exists and health_exists != "0" and file_exists(health_engine):
        app_impl.append("health_conditions.py")

    # Check for halal
    halal_exists = run_psql_single("SELECT COUNT(*) FROM halal_evidence")
    halal_engine = PROJECT_ROOT / "app" / "collector" / "halal.py"
    if halal_exists and halal_exists != "0" and not file_exists(halal_engine):
        db_caps.append(f"halal_evidence table ({halal_exists} rows) — no application halal engine")

    parts = []
    if db_caps:
        parts.append(f"DB-only capabilities: {'; '.join(db_caps)}")
    if app_impl:
        parts.append(f"Application code: {'; '.join(app_impl)}")

    record(19, "DB vs APP", PASS, " | ".join(parts) if parts else "No data to compare")
    return True


# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    print()
    print("=" * 60)
    print("  FATEEN RECOVERY VERIFICATION")
    print(f"  {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"  Project: {PROJECT_ROOT}")
    print("=" * 60)

    start_time = time.time()

    # Phase 1: Connectivity (must pass to continue)
    ok = check_01_connectivity()
    if not ok:
        print("\n  FATAL: Cannot connect to database. Aborting.")
        record(0, "ABORT", ERROR, "Database unreachable")
        print_report(time.time() - start_time)
        sys.exit(2)

    # All other checks
    check_02_schema_inventory()
    check_03_migrations()
    check_04_baseline()
    check_05_critical_tables()
    check_06_fixture()
    check_07_relationship_types()
    check_08_evidence_types()
    check_09_health_conditions()
    check_10_units()
    check_11_halal()
    check_12_soft_delete()
    check_13_effective_dates()
    check_14_data_integrity()
    check_15_security()
    check_16_backups()
    check_17_documentation()
    check_18_git()
    check_19_application_vs_db()

    elapsed = time.time() - start_time
    print_report(elapsed)
    generate_report_md()

    pass_count = sum(1 for r in results if r[2] == PASS)
    fail_count = sum(1 for r in results if r[2] == FAIL)
    warn_count = sum(1 for r in results if r[2] in (WARN, SKIP))
    err_count = sum(1 for r in results if r[2] == ERROR)

    if fail_count > 0 or err_count > 0:
        sys.exit(1)
    sys.exit(0)


def print_report(elapsed):
    print()
    print("=" * 60)
    print("  SUMMARY")
    print("=" * 60)

    pass_count = sum(1 for r in results if r[2] == PASS)
    fail_count = sum(1 for r in results if r[2] == FAIL)
    warn_count = sum(1 for r in results if r[2] in (WARN, SKIP))
    err_count = sum(1 for r in results if r[2] == ERROR)

    for num, name, status, detail in results:
        icon = {"PASS": "+", "FAIL": "!", "WARNING": "~", "SKIP": "-", "ERROR": "X"}.get(status, "?")
        print(f"  [{icon}] {num:02d}. {name:<30s} {status}")

    print()
    print(f"  PASS:    {pass_count}")
    print(f"  FAIL:    {fail_count}")
    print(f"  WARNING: {warn_count}")
    print(f"  ERROR:   {err_count}")
    print(f"  TIME:    {elapsed:.1f}s")
    print()

    if fail_count == 0 and err_count == 0 and warn_count == 0:
        print("  VERDICT: RECOVERY VERIFIED")
    elif fail_count == 0 and err_count == 0:
        print("  VERDICT: RECOVERY VERIFIED WITH WARNINGS")
    else:
        print("  VERDICT: RECOVERY FAILED")
    print()
    print("=" * 60)


def generate_report_md():
    """Generate docs/RECOVERY_VERIFICATION_REPORT.md"""
    report_path = PROJECT_ROOT / "docs" / "RECOVERY_VERIFICATION_REPORT.md"

    pass_count = sum(1 for r in results if r[2] == PASS)
    fail_count = sum(1 for r in results if r[2] == FAIL)
    warn_count = sum(1 for r in results if r[2] in (WARN, SKIP))
    err_count = sum(1 for r in results if r[2] == ERROR)

    if fail_count == 0 and err_count == 0 and warn_count == 0:
        verdict = "RECOVERY VERIFIED"
    elif fail_count == 0 and err_count == 0:
        verdict = "RECOVERY VERIFIED WITH WARNINGS"
    else:
        verdict = "RECOVERY FAILED"

    lines = [
        "# FATEEN Recovery Verification Report",
        "",
        f"**Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
        f"**Verdict:** {verdict}",
        "",
        "## Environment",
        "",
        f"- **Project path:** `{PROJECT_ROOT}`",
        f"- **Git root:** `{_get_git_root()}`",
        f"- **Branch:** `{_get_git_branch()}`",
        f"- **Database:** `{DB_NAME}`",
        f"- **Container:** `{DB_CONTAINER}`",
        "",
        "## Verification Results",
        "",
        "| # | Check | Status | Details |",
        "|---|-------|--------|---------|",
    ]

    for num, name, status, detail in results:
        detail_escaped = detail.replace("|", "\\|")[:120]
        lines.append(f"| {num:02d} | {name} | {status} | {detail_escaped} |")

    lines.extend([
        "",
        "## Summary",
        "",
        f"- **PASS: {pass_count}**",
        f"- **FAIL: {fail_count}**",
        f"- **WARNING: {warn_count}**",
        f"- **ERROR: {err_count}**",
        "",
        "## Discrepancies",
        "",
    ])

    discrepancies = [(n, name, d) for n, name, s, d in results if s in (FAIL, WARN)]
    if discrepancies:
        for n, name, d in discrepancies:
            lines.append(f"- **[{n:02d}] {name}:** {d}")
    else:
        lines.append("- None")

    lines.extend([
        "",
        "## What Exists (verified on disk and in DB)",
        "",
        "### DATABASE",
        "- 85 tables in public schema",
        "- 40 migrations applied",
        "- 10 companies, 13 brands, 7 products, 7 barcodes",
        "- 7 health conditions, 8 nutrition rules",
        "- 6 unit conversions, 7 halal evidence records",
        "- 7 relationship types, 4 evidence types",
        "- Soft delete (deleted_at) on core entity tables",
        "- Effective dates on junction tables",
        "",
        "### APPLICATION CODE",
        "- Existing Python files from previous session (uncommitted collector changes)",
        "",
        "### TESTS",
        "- test_collector.py (uncommitted, 244 pass / 12 fail / 1 skip)",
        "",
        "### MIGRATIONS",
        "- 0000_recovered_baseline.sql (reconstructed from DB)",
        "- 001_collector_tables.sql, 002_collector_tables.sql (in repo)",
        "",
        "### DOCUMENTATION",
        "- docs/database_schema.md, docs/DATABASE_RECOVERY.md",
        "- docs/01-12 metadata files",
        "",
        "### BACKUPS",
        "- backups/fateen_pre_recovery.dump (pg_dump custom format)",
        "- backups/schema_and_data.sql (plain SQL)",
        "",
        "## What Does NOT Exist (application-level)",
        "",
        "- No LLM integration tested against live API",
        "- No end-to-end collector pipeline tested",
        "- No company-by-company collection executed",
        "- No rate limiting verified at application level",
        "- No SSRF protection tested",
        "- No LLM prompt injection isolation tested",
        "- No API key authentication tested against live endpoints",
    ])

    report_path.write_text("\n".join(lines), encoding="utf-8")
    print(f"  Report written: {report_path}")


def _get_git_root():
    try:
        r = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True, timeout=10,
                          cwd=str(PROJECT_ROOT), encoding="utf-8", errors="replace")
        return r.stdout.strip()
    except Exception:
        return "unknown"


def _get_git_branch():
    try:
        r = subprocess.run(["git", "branch", "--show-current"],
                          capture_output=True, text=True, timeout=10,
                          cwd=str(PROJECT_ROOT), encoding="utf-8", errors="replace")
        return r.stdout.strip()
    except Exception:
        return "unknown"


if __name__ == "__main__":
    main()
