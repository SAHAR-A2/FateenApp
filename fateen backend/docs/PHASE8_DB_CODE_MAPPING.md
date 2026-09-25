# Phase 8 — Database-to-Code Mapping

**Date:** 2026-08-18
**Status:** IN PROGRESS

---

## Coverage Summary

| Metric | Count |
|--------|-------|
| Total DB tables | 85 |
| Tables referenced in code | 28 (33%) |
| Tables without code | 57 (67%) |
| Tables with test coverage | 20 |
| Tables without test coverage | 8 |

---

## Tables WITH Code Coverage

### Core Product Tables

| Table | Read By | Written By | Tests |
|-------|---------|-----------|-------|
| `products` | agent/ingestion, collector/dedup, collector/orchestrator, collector/coverage, collector/conflicts, repositories/barcode, repositories/product, services/barcode, services/product_details | agent/ingestion, collector/orchestrator | test_collector (P08, P15), test_integration (P8, P9) |
| `barcodes` | agent/ingestion, collector/dedup, collector/coverage, repositories/barcode, services/barcode, services/product_details | agent/ingestion | test_collector (P05), test_integration (P6, P7) |
| `product_barcodes` | agent/ingestion, collector/dedup, collector/coverage, repositories/barcode, services/barcode, services/product_details | agent/ingestion | test_collector (P15), test_integration (P6, P8) |
| `brands` | collector/dedup, collector/orchestrator, collector/coverage, collector/conflicts, repositories/company | — | test_collector (P03) |

### Ingredient / Allergen / Nutrition Tables

| Table | Read By | Written By | Tests |
|-------|---------|-----------|-------|
| `ingredients` | agent/ingestion, repositories/barcode, services/product_details | agent/ingestion | test_agent_ingestion |
| `product_ingredients` | agent/ingestion, collector/coverage, repositories/barcode, services/product_details | agent/ingestion | test_agent_ingestion, test_integration (P17) |
| `allergens` | agent/ingestion, repositories/barcode, services/product_details | agent/ingestion | test_agent_ingestion |
| `product_allergens` | agent/ingestion, collector/coverage, repositories/barcode, services/product_details | agent/ingestion | test_agent_ingestion, test_integration (P17) |
| `nutrition_types` | agent/ingestion, collector/units, collector/coverage, collector/health_conditions, services/product_details | — | test_agent_ingestion, test_integration (P17) |
| `product_nutrition_values` | agent/ingestion, collector/coverage, collector/health_conditions, services/product_details | agent/ingestion | test_agent_ingestion, test_integration (P17) |
| `units` | agent/ingestion, collector/units, collector/health_conditions, repositories/barcode, services/product_details | — | test_collector (P11), test_integration (P17) |
| `measurement_bases` | agent/ingestion, collector/health_conditions, services/product_details | — | test_agent_ingestion |

### Reference / Lookup Tables

| Table | Read By | Written By | Tests |
|-------|---------|-----------|-------|
| `relationship_types` | agent/ingestion, collector/sources, repositories/barcode, services/barcode, services/product_details | — | test_collector (P28), test_integration (P20) |
| `data_sources` | agent/ingestion, collector/sources, repositories/barcode, services/barcode | agent/ingestion | test_collector (P05) |
| `evidence_types` | collector/sources, repositories/barcode, services/barcode, services/product_details | — | test_collector (P13), test_integration (P20) |
| `lifecycle_statuses` | agent/ingestion, repositories/barcode, services/barcode, services/product_details | — | test_collector (P21) |

### Company Tables

| Table | Read By | Written By | Tests |
|-------|---------|-----------|-------|
| `companies` | collector/discovery, collector/orchestrator, collector/coverage, collector/prioritization, collector/reporting, repositories/company | collector/orchestrator, collector/prioritization | test_collector (P01, P03, P27) |

### Collector Tables

| Table | Read By | Written By | Tests |
|-------|---------|-----------|-------|
| `scan_jobs` | collector/orchestrator, collector/reporting, repositories/scan | collector/orchestrator | test_collector (P16, P17) |
| `scan_job_items` | collector/orchestrator, collector/reporting, repositories/scan | collector/orchestrator | test_collector (P16) |
| `discovery_candidates` | collector/discovery, collector/orchestrator, repositories/discovery | collector/discovery, collector/orchestrator | test_collector (P04) |
| `data_conflicts` | collector/conflicts, collector/orchestrator | collector/conflicts, collector/orchestrator | test_collector (P14) |
| `evidence_records` | collector/sources, collector/coverage | collector/sources | test_collector (P13) |
| `halal_evidence` | collector/halal | collector/halal | test_collector (P21) |
| `health_conditions` | collector/health_conditions | — | test_collector (P22) |
| `condition_nutrition_rules` | collector/health_conditions | — | test_collector (P22) |
| `product_health_evaluations` | collector/health_conditions | collector/health_conditions | test_collector (P22) |
| `unit_conversions` | collector/units | — | test_collector (P11) |

### Health Flags (Referenced but Not in Collector)

| Table | Read By | Written By | Tests |
|-------|---------|-----------|-------|
| `product_health_flags` | services/product_details | — | test_product_details |
| `health_flags` | services/product_details | — | test_product_details |

---

## Tables WITHOUT Code Coverage

### Foundation Tables (created in migrations 0001–0005)

| Table | Purpose | Seed Data | Priority for Code |
|-------|---------|-----------|-------------------|
| `countries` | Country reference | — | Medium |
| `languages` | Language reference | — | Medium |
| `verification_statuses` | Entity verification | — | Low |
| `approval_statuses` | Entity approval | — | Low |
| `translation_statuses` | Translation workflow | — | Low |
| `review_tiers` | Content review tiers | — | Low |
| `review_decisions` | Review decisions | — | Low |

### Entity Translation Tables

| Table | Purpose | Priority |
|-------|---------|----------|
| `product_translations` | Arabic/English product names | High |
| `brand_translations` | Arabic/English brand names | High |
| `company_translations` | Arabic/English company names | Medium |
| `ingredient_translations` | Arabic/English ingredient names | Medium |
| `allergen_translations` | Arabic/English allergen names | Medium |

### Product Extension Tables

| Table | Purpose | Priority |
|-------|---------|----------|
| `product_categories` | Category classification | High |
| `product_category_assignments` | Product-to-category mapping | High |
| `product_packaging` | Packaging details | Medium |
| `product_images` / `entity_media` | Product photos | Medium |
| `product_tags` / `entity_tags` | Tagging system | Low |

### Search Tables

| Table | Purpose | Priority |
|-------|---------|----------|
| `search_index` | Full-text search index | High |
| `search_suggestions` | Search suggestions | Medium |
| `search_analytics` | Search analytics | Low |

### History / Audit Tables (51+ rows exist in barcode_history)

| Table | Purpose | Priority |
|-------|---------|----------|
| `barcode_history` | Barcode scan history | Medium |
| `product_barcodes_history` | Product-barcode changes | Medium |
| `product_ingredients_history` | Ingredient changes | Low |
| `product_allergens_history` | Allergen changes | Low |
| `entity_versions` | Version tracking | Low |
| `version_changes` | Change details | Low |
| `version_relationships` | Version relationships | Low |

### ECR (External Change Request) Tables

| Table | Purpose | Priority |
|-------|---------|----------|
| `ecr_threads` | ECR threads | Low |
| `ecr_messages` | ECR messages | Low |
| `ecr_references` | ECR references | Low |

### Ingredient KB Tables

| Table | Purpose | Priority |
|-------|---------|----------|
| `ingredient_aliases` | Ingredient name aliases | High |
| `ingredient_allergens` | Ingredient-to-allergen mapping | High |

### Coverage / Versioning Tables

| Table | Purpose | Priority |
|-------|---------|----------|
| `coverage_snapshots` | Coverage history | Low (used in collector/coverage.py) |
| `data_versions` | Data versioning | Low |
| `schema_migrations` | Migration tracking | Low (managed by migration scripts) |

---

## Unreferenced Tables (No Code, No Seed Data)

These tables exist in the schema but have no code references and no seed data:

| Table Category | Tables | Count |
|---------------|--------|-------|
| Translation workflow | verification_statuses, approval_statuses, translation_statuses, review_tiers, review_decisions | 5 |
| ECR | ecr_threads, ecr_messages, ecr_references | 3 |
| Versioning | entity_versions, version_changes, version_relationships, data_versions | 4 |
| History | barcode_history, product_barcodes_history, product_ingredients_history, product_allergens_history | 4 |
| Search | search_index, search_suggestions, search_analytics | 3 |
| Product extension | product_categories, product_category_assignments, product_packaging, product_images/entity_media, product_tags/entity_tags | 5 |
| Translation | product_translations, brand_translations, company_translations, ingredient_translations, allergen_translations | 5 |
| Reference | countries, languages, ingredient_aliases, ingredient_allergens | 4 |
| Coverage | coverage_snapshots, schema_migrations | 2 |
| **TOTAL** | | **35** |

Note: Some of these tables DO have seed data (countries, languages, verification_statuses, etc.) but no application code reads from them.

---

## Layer Mapping

### API → Service/Repository → DB Table

```
/api/v1/products/{barcode}
  → barcode_service.get_product_by_barcode()
    → barcode_repository.find_product_details_by_barcode()
      → product_barcodes → products → barcodes
      → relationship_types, data_sources, evidence_types, lifecycle_statuses

/api/v1/products/{barcode}/details
  → product_details_service.get_product_details_by_barcode()
    → product_barcodes → products → barcodes → lifecycle_statuses
    → product_ingredients → ingredients → units
    → product_allergens → allergens
    → product_nutrition_values → nutrition_types → measurement_bases
    → product_health_flags → health_flags

/api/v1/agent/ingest
  → agent.ingestion.ingest()
    → products, barcodes, product_barcodes
    → ingredients, product_ingredients, units
    → allergens, product_allergens
    → nutrition_types, product_nutrition_values, measurement_bases
    → relationship_types, data_sources, evidence_types, lifecycle_statuses

/api/v1/companies
  → company_repository.*
    → companies, products, scan_jobs, brands

/api/v1/scan/*
  → scan_repository.*
    → scan_jobs, scan_job_items
  → discovery_repository.*
    → discovery_candidates

/api/v1/enrichment/extract
  → llm.extractor.extract_product_data()
    → (no DB — returns structured data)

/api/v1/enrichment/enrich
  → llm.extractor.enrich_product()
    → (no DB — returns suggestions)
```

---

## Code-to-DB Dependency Graph

```
app/main.py
├── app/api/products.py → services/barcode_service.py → repositories/barcode_repository.py
├── app/api/product_details.py → services/product_details_service.py
├── app/api/companies.py → repositories/company_repository.py
├── app/api/scan.py → repositories/scan_repository.py, discovery_repository.py
├── app/api/ingestion.py → agent/ingestion.py
├── app/api/enrichment.py → llm/extractor.py
└── app/db/health.py → (sys queries)

agent/ingestion.py
├── Reads: products, barcodes, product_barcodes, ingredients, allergens,
│         nutrition_types, units, measurement_bases, relationship_types,
│         data_sources, evidence_types, lifecycle_statuses
└── Writes: product_ingredients, product_allergens, product_nutrition_values

collector/orchestrator.py
├── Reads: companies, products, brands, scan_jobs, scan_job_items
├── Writes: scan_jobs, scan_job_items, discovery_candidates, data_conflicts
└── Delegates to: deduplication, conflicts, health_conditions, halal, coverage

collector/sources.py
├── Reads: data_sources, evidence_types, relationship_types
└── Writes: evidence_records

collector/deduplication.py
├── Reads: product_barcodes, products, barcodes, brands
└── Writes: (none — read-only)

collector/health_conditions.py
├── Reads: health_conditions, condition_nutrition_rules,
│         product_nutrition_values, nutrition_types, units, measurement_bases
└── Writes: product_health_evaluations
```
