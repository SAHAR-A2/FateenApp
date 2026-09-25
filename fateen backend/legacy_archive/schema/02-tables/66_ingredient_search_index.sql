-- =============================================================================
-- Table: ingredient_search_index
-- -----------------------------------------------------------------------------
-- Purpose:       Search index for ingredients. A DERIVED READ MODEL, not
--                canonical data: it holds a normalized, denormalized copy of the
--                ingredient's searchable text so that search never scans the
--                canonical registry. Completely disposable and rebuildable from
--                canonical ingredients/ingredient_translations/aliases.
-- Work orders:   Mission 08: Search Layer (Derived Read Models).
-- Dependencies:  Extensions pg_trgm / citext (0001). Canonical ingredients and
--                ingredient_translations (0012), ingredient_aliases (0016) -
--                referenced LOGICALLY ONLY; there is no foreign key, by design.
-- Migration:     0030_search_tables.sql
-- Rationale:     Canonical entities remain the single source of truth; search
--                owns performance. The ingredient_id column is a logical
--                reference without a FOREIGN KEY constraint so the whole layer
--                can be dropped and rebuilt at any time. UNIQUE (ingredient_id)
--                keeps one row per canonical ingredient, making rebuilds
--                idempotent (truncate + reload, or upsert). No lifecycle,
--                governance, or audit columns: those live on the canonical
--                entity and must not be duplicated (Mission 08 rules).
--                generated_at records when the row was built/refreshed.
-- Deviation:     The standard column layout (audit trio, status_id,
--                version_number) is intentionally NOT followed - this is a
--                derived read model, not a governed entity.
-- Columns:
--   ingredient_id     Logical reference to ingredients.id (NO FK by design).
--   search_name       Normalized primary searchable name (lowercased, folded).
--   search_text       Normalized concatenated searchable text (description,
--                     category, aliases - application-built).
--   search_tokens     Language-independent normalized search tokens.
--   language_codes    Languages the searchable text covers (citext codes).
--   search_rank       Ranking helper >= 0 (higher = more prominent).
--   generated_at      When this search row was generated/refreshed.
-- =============================================================================
CREATE TABLE ingredient_search_index (
    id             uuid        NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    ingredient_id  uuid        NOT NULL,
    search_name    text        NOT NULL,
    search_text    text        NOT NULL,
    search_tokens  text[]      NOT NULL DEFAULT '{}'::text[],
    language_codes citext[]    NOT NULL DEFAULT '{}'::citext[],
    search_rank    numeric     NOT NULL DEFAULT 0,
    generated_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT ingredient_search_index_ingredient_id_unique
        UNIQUE (ingredient_id),
    CONSTRAINT ingredient_search_index_search_rank_check
        CHECK (search_rank >= 0)
);

COMMENT ON TABLE ingredient_search_index IS
    'Derived, rebuildable search index for ingredients (read model; no FK to ingredients).';
COMMENT ON COLUMN ingredient_search_index.ingredient_id IS
    'Logical reference to ingredients.id; NO foreign key - the search layer is disposable and rebuildable.';
COMMENT ON COLUMN ingredient_search_index.search_name IS
    'Normalized primary searchable name (application-built from canonical name/translations).';
COMMENT ON COLUMN ingredient_search_index.search_text IS
    'Normalized concatenated searchable text: description, category, aliases.';
COMMENT ON COLUMN ingredient_search_index.search_tokens IS
    'Language-independent normalized search tokens (folded, accent-stripped).';
COMMENT ON COLUMN ingredient_search_index.language_codes IS
    'Languages covered by the searchable text (citext codes, e.g. {ar,en}).';
COMMENT ON COLUMN ingredient_search_index.search_rank IS
    'Ranking helper >= 0; higher means the result is promoted.';
COMMENT ON COLUMN ingredient_search_index.generated_at IS
    'Timestamp when this search row was generated or refreshed (rebuild tracking).';
