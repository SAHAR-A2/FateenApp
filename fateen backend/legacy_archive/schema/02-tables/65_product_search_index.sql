-- =============================================================================
-- Table: product_search_index
-- -----------------------------------------------------------------------------
-- Purpose:       Search index for products. A DERIVED READ MODEL, not canonical
--                data: it holds a normalized, denormalized copy of the product's
--                searchable text so that search never scans the canonical
--                registry. Completely disposable and rebuildable from canonical
--                products/product_translations.
-- Work orders:   Mission 08: Search Layer (Derived Read Models).
-- Dependencies:  Extensions pg_trgm / citext (0001). Canonical products and
--                product_translations (0012), product_categories (0008),
--                brands (0012) - referenced LOGICALLY ONLY; there is no foreign
--                key, by design.
-- Migration:     0030_search_tables.sql
-- Rationale:     Canonical entities remain the single source of truth; search
--                owns performance. The product_id column is a logical reference
--                without a FOREIGN KEY constraint so the whole layer can be
--                dropped and rebuilt at any time. UNIQUE (product_id) keeps one
--                row per canonical product, making rebuilds idempotent
--                (truncate + reload, or upsert). No lifecycle, governance, or
--                audit columns: those live on the canonical entity and must not
--                be duplicated (Mission 08 rules). generated_at records when the
--                row was built/refreshed.
-- Deviation:     The standard column layout (audit trio, status_id,
--                version_number) is intentionally NOT followed - this is a
--                derived read model, not a governed entity.
-- Columns:
--   product_id        Logical reference to products.id (NO FK by design).
--   search_name       Normalized primary searchable name (lowercased, folded).
--   search_text       Normalized concatenated searchable text (description,
--                     category, brand, code, aliases - application-built).
--   search_tokens     Language-independent normalized search tokens.
--   language_codes    Languages the searchable text covers (citext codes).
--   search_rank       Ranking helper >= 0 (higher = more prominent).
--   generated_at      When this search row was generated/refreshed.
-- =============================================================================
CREATE TABLE product_search_index (
    id             uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    product_id     uuid        NOT NULL,
    search_name    text        NOT NULL,
    search_text    text        NOT NULL,
    search_tokens  text[]      NOT NULL DEFAULT '{}'::text[],
    language_codes citext[]    NOT NULL DEFAULT '{}'::citext[],
    search_rank    numeric     NOT NULL DEFAULT 0,
    generated_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT product_search_index_product_id_unique
        UNIQUE (product_id),
    CONSTRAINT product_search_index_search_rank_check
        CHECK (search_rank >= 0)
);

COMMENT ON TABLE product_search_index IS
    'Derived, rebuildable search index for products (read model; no FK to products).';
COMMENT ON COLUMN product_search_index.product_id IS
    'Logical reference to products.id; NO foreign key - the search layer is disposable and rebuildable.';
COMMENT ON COLUMN product_search_index.search_name IS
    'Normalized primary searchable name (application-built from canonical name/translations).';
COMMENT ON COLUMN product_search_index.search_text IS
    'Normalized concatenated searchable text: description, category, brand, internal code, aliases.';
COMMENT ON COLUMN product_search_index.search_tokens IS
    'Language-independent normalized search tokens (folded, accent-stripped).';
COMMENT ON COLUMN product_search_index.language_codes IS
    'Languages covered by the searchable text (citext codes, e.g. {ar,en}).';
COMMENT ON COLUMN product_search_index.search_rank IS
    'Ranking helper >= 0; higher means the result is promoted.';
COMMENT ON COLUMN product_search_index.generated_at IS
    'Timestamp when this search row was generated or refreshed (rebuild tracking).';
