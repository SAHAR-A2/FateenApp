# =============================================================================
# build_migrations.ps1 - regenerate versioned migration files from schema/
# -----------------------------------------------------------------------------
# The canonical DDL lives decomposed in schema/ (00-extensions .. 07-triggers).
# This script assembles those files, in a fixed, dependency-safe order, into the
# versioned migrations that scripts/migrate.ps1 applies to PostgreSQL.
#
# Workflow:  edit schema/  ->  run this script  ->  review the migration diff
#            ->  commit. Migrations are generated, never edited by hand.
#
# Run:  powershell -ExecutionPolicy Bypass -File scripts/build_migrations.ps1
# =============================================================================

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot | Split-Path -Parent

function Read-Text([string]$path) {
    return [System.IO.File]::ReadAllText($path)
}

function Write-Text([string]$path, [string]$content) {
    [System.IO.File]::WriteAllText($path, $content)
}

# Migration manifest: number -> (title, ordered schema files).
# Order here IS the migration order. Do not reorder without updating the docs.
$manifest = @(
    @{
        number = '0001'
        title  = 'foundation_extensions'
        files  = @(
            'schema\00-extensions\01_extensions.sql'
        )
    },
    @{
        number = '0002'
        title  = 'foundation_enums'
        files  = @(
            'schema\01-enums\01_entity_status.sql',
            'schema\01-enums\02_approval_status.sql',
            'schema\01-enums\03_review_tier.sql',
            'schema\01-enums\04_review_decision.sql',
            'schema\01-enums\05_version_status.sql',
            'schema\01-enums\06_confidence_band.sql',
            'schema\01-enums\07_translation_status.sql',
            'schema\01-enums\08_candidate_status.sql',
            'schema\01-enums\09_update_type.sql',
            'schema\01-enums\10_unit_dimension.sql'
        )
    },
    @{
        number = '0003'
        title  = 'foundation_lookup_tables'
        files  = @(
            'schema\02-tables\01_lifecycle_statuses.sql',
            'schema\02-tables\02_languages.sql',
            'schema\02-tables\03_countries.sql',
            'schema\02-tables\04_units.sql',
            'schema\02-tables\05_package_types.sql',
            'schema\02-tables\06_barcode_types.sql',
            'schema\02-tables\07_image_types.sql',
            'schema\02-tables\08_relationship_types.sql',
            'schema\02-tables\09_source_types.sql',
            'schema\02-tables\10_source_priorities.sql',
            'schema\02-tables\11_data_sources.sql',
            'schema\02-tables\12_health_flag_types.sql'
        )
    },
    @{
        number = '0004'
        title  = 'foundation_lookup_constraints'
        files  = @(
            'schema\03-constraints\01_relationship_types.sql',
            'schema\03-constraints\02_data_sources.sql',
            'schema\03-constraints\03_lookup_status_fks.sql'
        )
    },
    @{
        number = '0005'
        title  = 'foundation_lookup_indexes'
        files  = @(
            'schema\04-indexes\01_units.sql',
            'schema\04-indexes\02_relationship_types.sql',
            'schema\04-indexes\03_data_sources.sql',
            'schema\04-indexes\04_lookup_statuses.sql'
        )
    },
    @{
        number = '0006'
        title  = 'foundation_functions_and_triggers'
        files  = @(
            'schema\06-functions\01_set_updated_at.sql',
            'schema\07-triggers\01_lookup_tables_updated_at.sql'
        )
    },
    @{
        number = '0007'
        title  = 'seed_lifecycle_statuses'
        files  = @(
            'seed\00-system\01_lifecycle_statuses.sql'
        )
    },
    @{
        number = '0008'
        title  = 'foundation_reference_tables'
        files  = @(
            'schema\02-tables\13_regions.sql',
            'schema\02-tables\14_ingredient_categories.sql',
            'schema\02-tables\15_product_categories.sql',
            'schema\02-tables\16_allergen_types.sql',
            'schema\02-tables\17_nutrition_types.sql',
            'schema\02-tables\18_regulatory_authorities.sql',
            'schema\02-tables\19_evidence_types.sql',
            'schema\02-tables\20_role_types.sql',
            'schema\02-tables\21_permission_types.sql',
            'schema\02-tables\22_audit_event_types.sql'
        )
    },
    @{
        number = '0009'
        title  = 'foundation_reference_constraints'
        files  = @(
            'schema\03-constraints\04_mission02_fks.sql'
        )
    },
    @{
        number = '0010'
        title  = 'foundation_reference_indexes'
        files  = @(
            'schema\04-indexes\05_mission02.sql'
        )
    },
    @{
        number = '0011'
        title  = 'foundation_reference_triggers'
        files  = @(
            'schema\07-triggers\02_mission02_tables_updated_at.sql'
        )
    },
    @{
        number = '0012'
        title  = 'core_entity_tables'
        files  = @(
            'schema\02-tables\23_companies.sql',
            'schema\02-tables\24_company_translations.sql',
            'schema\02-tables\25_brands.sql',
            'schema\02-tables\26_brand_translations.sql',
            'schema\02-tables\27_products.sql',
            'schema\02-tables\28_product_translations.sql',
            'schema\02-tables\29_ingredients.sql',
            'schema\02-tables\30_ingredient_translations.sql',
            'schema\02-tables\31_allergens.sql',
            'schema\02-tables\32_allergen_translations.sql',
            'schema\02-tables\33_nutrition_type_translations.sql',
            'schema\02-tables\34_product_category_translations.sql',
            'schema\02-tables\35_health_flags.sql',
            'schema\02-tables\36_health_flag_translations.sql'
        )
    },
    @{
        number = '0013'
        title  = 'core_entity_constraints'
        files  = @(
            'schema\03-constraints\05_core_entities.sql'
        )
    },
    @{
        number = '0014'
        title  = 'core_entity_indexes'
        files  = @(
            'schema\04-indexes\06_core_entities.sql'
        )
    },
    @{
        number = '0015'
        title  = 'core_entity_triggers'
        files  = @(
            'schema\07-triggers\03_core_entities_updated_at.sql'
        )
    },
    @{
        number = '0016'
        title  = 'relationship_tables'
        files  = @(
            'schema\02-tables\37_product_ingredients.sql',
            'schema\02-tables\38_product_allergens.sql',
            'schema\02-tables\39_product_nutrition_values.sql',
            'schema\02-tables\40_product_health_flags.sql',
            'schema\02-tables\41_ingredient_allergens.sql',
            'schema\02-tables\42_ingredient_health_flags.sql',
            'schema\02-tables\43_ingredient_aliases.sql',
            'schema\02-tables\44_entity_relationships.sql'
        )
    },
    @{
        number = '0017'
        title  = 'relationship_constraints'
        files  = @(
            'schema\03-constraints\06_relationships.sql'
        )
    },
    @{
        number = '0018'
        title  = 'relationship_indexes'
        files  = @(
            'schema\04-indexes\07_relationships.sql'
        )
    },
    @{
        number = '0019'
        title  = 'relationship_triggers'
        files  = @(
            'schema\07-triggers\04_relationships_updated_at.sql'
        )
    },
    @{
        number = '0020'
        title  = 'history_tables'
        files  = @(
            'schema\02-tables\45_companies_history.sql',
            'schema\02-tables\46_brands_history.sql',
            'schema\02-tables\47_products_history.sql',
            'schema\02-tables\48_ingredients_history.sql',
            'schema\02-tables\49_allergens_history.sql',
            'schema\02-tables\50_health_flags_history.sql',
            'schema\02-tables\51_nutrition_types_history.sql',
            'schema\02-tables\52_product_categories_history.sql',
            'schema\02-tables\53_ingredient_categories_history.sql'
        )
    },
    @{
        number = '0021'
        title  = 'audit_tables'
        files  = @(
            'schema\02-tables\54_audit_context.sql',
            'schema\02-tables\55_change_sets.sql',
            'schema\02-tables\56_audit_events.sql',
            'schema\02-tables\57_audit_log.sql',
            'schema\02-tables\58_entity_versions.sql',
            'schema\02-tables\59_version_metadata.sql'
        )
    },
    @{
        number = '0022'
        title  = 'history_constraints'
        files  = @(
            'schema\03-constraints\07_history_and_audit.sql'
        )
    },
    @{
        number = '0023'
        title  = 'history_indexes'
        files  = @(
            'schema\04-indexes\08_history_and_audit.sql'
        )
    },
    @{
        number = '0024'
        title  = 'history_triggers'
        files  = @(
            'schema\06-functions\02_prevent_history_mutation.sql',
            'schema\07-triggers\05_history_immutability.sql',
            'schema\07-triggers\06_audit_tables_updated_at.sql'
        )
    },
    @{
        number = '0025'
        title  = 'media_and_barcode_tables'
        files  = @(
            'schema\02-tables\60_verification_statuses.sql',
            'schema\02-tables\61_images.sql',
            'schema\02-tables\62_barcodes.sql'
        )
    },
    @{
        number = '0026'
        title  = 'media_and_barcode_history_tables'
        files  = @(
            'schema\02-tables\63_images_history.sql',
            'schema\02-tables\64_barcodes_history.sql'
        )
    },
    @{
        number = '0027'
        title  = 'media_and_barcode_constraints'
        files  = @(
            'schema\03-constraints\08_media_and_barcodes.sql'
        )
    },
    @{
        number = '0028'
        title  = 'media_and_barcode_indexes'
        files  = @(
            'schema\04-indexes\09_media_and_barcodes.sql'
        )
    },
    @{
        number = '0029'
        title  = 'media_and_barcode_triggers'
        files  = @(
            'schema\07-triggers\07_media_and_barcode_tables_updated_at.sql',
            'schema\07-triggers\08_media_and_barcode_history_immutability.sql'
        )
    },
    @{
        number = '0030'
        title  = 'search_tables'
        files  = @(
            'schema\02-tables\65_product_search_index.sql',
            'schema\02-tables\66_ingredient_search_index.sql',
            'schema\02-tables\67_brand_search_index.sql',
            'schema\02-tables\68_company_search_index.sql'
        )
    },
    @{
        number = '0031'
        title  = 'search_indexes'
        files  = @(
            'schema\04-indexes\10_search_indexes.sql'
        )
    },
    @{
        number = '0032'
        title  = 'ecr_product_media_tables'
        files  = @(
            'schema\02-tables\69_measurement_bases.sql',
            'schema\02-tables\70_product_images.sql',
            'schema\02-tables\71_product_barcodes.sql'
        )
    },
    @{
        number = '0033'
        title  = 'ecr_product_media_history_tables'
        files  = @(
            'schema\02-tables\72_product_images_history.sql',
            'schema\02-tables\73_product_barcodes_history.sql'
        )
    },
    @{
        number = '0034'
        title  = 'ecr_constraints'
        files  = @(
            'schema\03-constraints\09_measurement_basis.sql',
            'schema\03-constraints\10_product_media.sql'
        )
    },
    @{
        number = '0035'
        title  = 'ecr_indexes'
        files  = @(
            'schema\04-indexes\11_measurement_basis.sql',
            'schema\04-indexes\12_product_media.sql'
        )
    },
    @{
        number = '0036'
        title  = 'ecr_functions'
        files  = @(
            'schema\06-functions\03_capture_entity_history.sql',
            'schema\06-functions\04_validate_entity_relationship_endpoints.sql'
        )
    },
    @{
        number = '0037'
        title  = 'ecr_triggers'
        files  = @(
            'schema\07-triggers\09_ecr_capture_history.sql',
            'schema\07-triggers\10_entity_relationships_validate_endpoints.sql',
            'schema\07-triggers\11_ecr_new_tables_updated_at.sql',
            'schema\07-triggers\12_ecr_history_immutability.sql'
        )
    },
    @{
        number = '0038'
        title  = 'ecr_fix_capture_history'
        files  = @(
            'schema\06-functions\05_ecr_fix_capture_entity_history.sql'
        )
    },
    @{
        number = '0039'
        title  = 'ecr_fix_history_original_entity_fk'
        files  = @(
            'schema\03-constraints\11_ecr_fix_history_original_entity_fk.sql'
        )
    }
)

$divider = '-- ' + ('=' * 77)
$nl = "`n"

foreach ($m in $manifest) {
    $outPath = Join-Path $root ("migrations\{0}_{1}.sql" -f $m.number, $m.title)
    $body = New-Object System.Text.StringBuilder
    $null = $body.Append($divider + $nl)
    $null = $body.Append("-- MIGRATION $($m.number) - $($m.title)" + $nl)
    $null = $body.Append('-- -----------------------------------------------------------------------------' + $nl)
    $null = $body.Append("-- Purpose:       Assembles the $($m.files.Count) canonical object file(s) below into a" + $nl)
    $null = $body.Append('--                single deployable migration. See the referenced schema files for' + $nl)
    $null = $body.Append('--                full per-object documentation.' + $nl)
    $null = $body.Append('-- Dependencies:  Prior migrations (lower numbers) must be applied first.' + $nl)
    $null = $body.Append('-- Rationale:     Applied atomically by scripts/migrate.ps1 and recorded in the' + $nl)
    $null = $body.Append('--                schema_migrations ledger with a content checksum.' + $nl)
    $null = $body.Append("-- Generated by:  scripts/build_migrations.ps1 - DO NOT EDIT BY HAND." + $nl)
    $null = $body.Append($divider + $nl + $nl)

    foreach ($rel in $m.files) {
        $abs = Join-Path $root $rel
        if (-not (Test-Path -LiteralPath $abs)) {
            throw "Missing schema file: $rel"
        }
        $null = $body.Append("-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" + $nl)
        $null = $body.Append("-- Source file: $rel" + $nl)
        $null = $body.Append('-- ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' + $nl)
        $null = $body.Append((Read-Text $abs).TrimEnd() + $nl + $nl)
    }

    $content = $body.ToString().TrimEnd() + $nl
    Write-Text $outPath $content
    Write-Host ("wrote {0}_{1}.sql ({2} bytes)" -f $m.number, $m.title, $content.Length)
}

Write-Host 'Migration files regenerated from schema/.'
