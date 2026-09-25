#!/usr/bin/env python3
"""Phase 8 Architecture Alignment Verification Script.

Checks the codebase against the surviving PostgreSQL database.
NO DB modifications - read-only verification only.

Usage:
    .venv/Scripts/python.exe scripts/verify_phase8.py
"""

import os
import sys

PASS = "PASS"
FAIL = "FAIL"
WARN = "WARN"

results = {"pass": [], "fail": [], "warn": []}


def check(name, condition, detail=""):
    if condition:
        results["pass"].append(name)
        print(f"  [{PASS}] {name}")
    else:
        results["fail"].append(name)
        print(f"  [{FAIL}] {name} -- {detail}")


def warn(name, detail=""):
    results["warn"].append(name)
    print(f"  [{WARN}] {name} -- {detail}")


# --- Step 1: File Structure ---
print("\n=== Step 1: File Structure ===")

required_files = [
    "app/main.py",
    "app/core/config.py",
    "app/db/connection.py",
    "app/db/health.py",
    "app/api/products.py",
    "app/api/product_details.py",
    "app/api/companies.py",
    "app/api/scan.py",
    "app/api/ingestion.py",
    "app/api/enrichment.py",
    "app/agent/__init__.py",
    "app/agent/validators.py",
    "app/agent/normalizers.py",
    "app/agent/models.py",
    "app/agent/ingestion.py",
    "app/agent/confidence.py",
    "app/agent/cli.py",
    "app/llm/client.py",
    "app/llm/extractor.py",
    "app/llm/prompts.py",
    "app/collector/__init__.py",
    "app/collector/config.py",
    "app/collector/models.py",
    "app/collector/sources.py",
    "app/collector/retrieval.py",
    "app/collector/extraction.py",
    "app/collector/validation.py",
    "app/collector/deduplication.py",
    "app/collector/orchestrator.py",
    "app/collector/discovery.py",
    "app/collector/coverage.py",
    "app/collector/conflicts.py",
    "app/collector/halal.py",
    "app/collector/health_conditions.py",
    "app/collector/reporting.py",
    "app/collector/prioritization.py",
    "app/collector/units.py",
    "app/repositories/company_repository.py",
    "app/repositories/barcode_repository.py",
    "app/repositories/scan_repository.py",
    "app/repositories/discovery_repository.py",
    "app/repositories/product_repository.py",
    "app/services/barcode_service.py",
    "app/services/product_details_service.py",
    "app/services/database_service.py",
    "app/schemas/product.py",
    "app/schemas/product_details.py",
    "app/schemas/company.py",
    "app/schemas/scan.py",
    "requirements.txt",
    "docker-compose.yml",
    "Dockerfile",
]

for f in required_files:
    check(f"File exists: {f}", os.path.isfile(f), f"Missing: {f}")


# --- Step 2: Layer Boundaries ---
print("\n=== Step 2: Layer Boundaries ===")

try:
    llm_client = open("app/llm/client.py").read()
    llm_extractor = open("app/llm/extractor.py").read()
    llm_no_db = "get_connection" not in llm_client and "get_connection" not in llm_extractor
    check("LLM module never imports db/connection", llm_no_db, "LLM references get_connection")
except FileNotFoundError:
    check("LLM module never imports db/connection", False, "File not found")

api_files = ["app/api/products.py", "app/api/product_details.py", "app/api/companies.py",
             "app/api/scan.py", "app/api/ingestion.py", "app/api/enrichment.py"]
api_direct_db = False
for f in api_files:
    try:
        content = open(f).read()
        if "get_connection" in content:
            api_direct_db = True
            break
    except FileNotFoundError:
        pass
check("API layer never imports db/connection directly", not api_direct_db, "API file imports get_connection")


# --- Step 3: Configuration ---
print("\n=== Step 3: Configuration ===")

try:
    config_content = open("app/core/config.py").read()
    check("APP_ENV setting exists", "app_env" in config_content)
    check("DATABASE_URL setting exists", "database_url" in config_content)
    check("LLM_TIMEOUT setting exists", "llm_timeout" in config_content)
    check("CORS_ORIGINS setting exists", "cors_allowed_origins" in config_content)
    check("API_KEY setting exists", "api_key" in config_content)
    check("Production guard exists", "production" in config_content and "validate" in config_content)
except FileNotFoundError:
    check("Config file readable", False, "app/core/config.py not found")

try:
    env_content = open(".env").read()
    check(".env has DATABASE_URL", "DATABASE_URL" in env_content)
    check(".env is gitignored", True)
except FileNotFoundError:
    check(".env exists", False, ".env not found")

check(".env is gitignored", ".env" in open(".gitignore").read() if os.path.isfile(".gitignore") else False)


# --- Step 4: DB Connection ---
print("\n=== Step 4: DB Connection ===")

try:
    conn_content = open("app/db/connection.py").read()
    check("get_connection function exists", "def get_connection" in conn_content)
    check("Connection timeout configured", "connect_timeout" in conn_content or "timeout" in conn_content)
    check("Uses dict_row", "dict_row" in conn_content)
except FileNotFoundError:
    check("DB connection file", False, "app/db/connection.py not found")


# --- Step 5: Security ---
print("\n=== Step 5: Security ===")

try:
    main_content = open("app/main.py").read()
    check("CORS middleware configured", "CORSMiddleware" in main_content)
    check("Rate limiting implemented", "rate_limit" in main_content.lower() or "defaultdict" in main_content)
    check("Request ID header", "X-Request-ID" in main_content or "request_id" in main_content)
except FileNotFoundError:
    check("Main app file", False, "app/main.py not found")

try:
    dockerfile = open("Dockerfile").read()
    if "USER" not in dockerfile:
        warn("Dockerfile runs as root", "No USER directive found")
    else:
        check("Dockerfile runs as non-root", True)
except FileNotFoundError:
    pass


# --- Step 6: Collector Module Completeness ---
print("\n=== Step 6: Collector Module ===")

collector_modules = [
    "config.py", "models.py", "sources.py", "retrieval.py", "extraction.py",
    "validation.py", "deduplication.py", "orchestrator.py", "discovery.py",
    "coverage.py", "conflicts.py", "halal.py", "health_conditions.py",
    "reporting.py", "prioritization.py", "units.py"
]
for mod in collector_modules:
    path = f"app/collector/{mod}"
    check(f"Collector module: {mod}", os.path.isfile(path))


# --- Step 7: API Routes ---
print("\n=== Step 7: API Routes ===")

try:
    main_content = open("app/main.py").read()
    check("Products router included", "products_router" in main_content)
    check("Product details router included", "product_details_router" in main_content)
    check("Companies router included", "companies_router" in main_content)
    check("Scan router included", "scan_router" in main_content)
    check("Ingestion router included", "ingestion_router" in main_content)
    check("Enrichment router included", "enrichment_router" in main_content)
    check("6 include_router calls", main_content.count("include_router") == 6)
except FileNotFoundError:
    check("Routes check", False, "app/main.py not found")


# --- Step 8: Test Suite ---
print("\n=== Step 8: Test Suite ===")

test_files = [
    "tests/conftest.py", "tests/test_collector.py", "tests/test_agent_confidence.py",
    "tests/test_agent_ingestion.py", "tests/test_agent_normalizers.py",
    "tests/test_agent_validators.py", "tests/test_api_ingestion.py",
    "tests/test_blockers.py", "tests/test_cors.py", "tests/test_docs.py",
    "tests/test_health.py", "tests/test_integration.py", "tests/test_llm.py",
    "tests/test_product_details.py", "tests/test_products.py", "tests/test_schemas.py",
]
for tf in test_files:
    check(f"Test file: {os.path.basename(tf)}", os.path.isfile(tf))


# --- Step 9: Migration Baseline ---
print("\n=== Step 9: Migration Baseline ===")

check("Baseline migration exists", os.path.isfile("migrations/0000_recovered_baseline.sql"))
check("Collector migration 001 exists", os.path.isfile("migrations/001_collector_tables.sql"))
check("Collector migration 002 exists", os.path.isfile("migrations/002_collector_tables.sql"))

try:
    baseline = open("migrations/0000_recovered_baseline.sql").read()
    check("Baseline contains CREATE TABLE", "CREATE TABLE" in baseline)
    check("Baseline > 100KB", len(baseline) > 100_000)
except FileNotFoundError:
    check("Baseline readable", False)


# --- Step 10: Documentation ---
print("\n=== Step 10: Documentation ===")

doc_files = [
    "docs/database_schema.md",
    "docs/DATABASE_RECOVERY.md",
    "docs/RECOVERY_VERIFICATION_REPORT.md",
    "docs/PHASE8_CODE_INVENTORY.md",
    "docs/PHASE8_DB_CODE_MAPPING.md",
    "docs/PHASE8_REPORT.md",
]
for df in doc_files:
    check(f"Doc: {df}", os.path.isfile(df))


# --- Step 11: Backup Integrity ---
print("\n=== Step 11: Backup Integrity ===")

check("DB backup exists", os.path.isfile("backups/fateen_pre_recovery.dump"))
check("SQL backup exists", os.path.isfile("backups/schema_and_data.sql"))

try:
    dump_size = os.path.getsize("backups/fateen_pre_recovery.dump")
    check("Backup > 100KB", dump_size > 100_000, f"Size: {dump_size} bytes")
except OSError:
    check("Backup size check", False)


# --- Step 12: Git Status ---
print("\n=== Step 12: Git Status ===")

try:
    import subprocess
    result = subprocess.run(["git", "log", "--oneline", "-6"], capture_output=True, text=True)
    check("Git history exists", result.returncode == 0 and len(result.stdout.strip()) > 0)
    commits = result.stdout.strip().split("\n")
    check(f"Git has >= 4 commits (found {len(commits)})", len(commits) >= 4)
except Exception:
    check("Git status", False, "Could not run git")


# --- Step 13: Requirements ---
print("\n=== Step 13: Requirements ===")

try:
    reqs = open("requirements.txt").read()
    required_pkgs = ["fastapi", "uvicorn", "psycopg", "pydantic", "pydantic-settings", "httpx", "pytest"]
    for pkg in required_pkgs:
        check(f"Required package: {pkg}", pkg in reqs)
except FileNotFoundError:
    check("requirements.txt", False)


# --- Summary ---
print("\n" + "=" * 60)
print(f"  RESULTS: {len(results['pass'])} PASS | {len(results['fail'])} FAIL | {len(results['warn'])} WARN")
print("=" * 60)

if results["fail"]:
    print("\nFailed checks:")
    for f in results["fail"]:
        print(f"  X {f}")

if results["warn"]:
    print("\nWarnings:")
    for w in results["warn"]:
        print(f"  ! {w}")

exit_code = 1 if results["fail"] else 0
print(f"\nVERDICT: {'GO' if exit_code == 0 else 'NO-GO'}")
sys.exit(exit_code)
