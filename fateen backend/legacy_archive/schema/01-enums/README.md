# Enums

`CREATE TYPE ... AS ENUM` definitions.

**Policy (`ADR-001`, `ADR-007`):** ENUMs are allowed ONLY for internal immutable
system state (statuses, decisions, tiers, dimensions). Never add an ENUM for
governed, translatable, or evolving business knowledge — those are lookup tables
in `schema/02-tables/`. Future additions must never require `ALTER TYPE`.

Every enum file header records the specific immutable-state justification.
Current inventory (10): `entity_status`, `approval_status`, `review_tier`,
`review_decision`, `version_status`, `confidence_band`, `translation_status`,
`candidate_status`, `update_type`, `unit_dimension`.
