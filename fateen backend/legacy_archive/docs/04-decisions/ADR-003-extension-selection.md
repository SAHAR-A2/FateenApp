# ADR-003 — Extension Selection

**Status:** Accepted (Foundation Layer, work order #1)
**Date:** Foundation Layer milestone

## Context

The mission requires enabling only extensions that are truly required, each with
an in-file justification. Candidates: `uuid-ossp`, `pgcrypto`, `citext`, `pg_trgm`.

## Decision

Enabled:

| Extension  | Justification |
| ---------- | ------------- |
| `pgcrypto` | `digest()`/`hmac()` for canonical content hashing (deduplication and integrity in the population pipeline); `crypt()`/`gen_salt()` for the future identity/access milestone. |
| `citext`   | Case-insensitive natural-code columns (`languages.code`, `countries.code`, ...) so case-insensitive uniqueness is enforced by the type system. |
| `pg_trgm`  | Trigram similarity operators + GIN support required for high-performance search and pipeline name-matching/deduplication. |

NOT enabled:

| Extension  | Why not |
| ---------- | ------- |
| `uuid-ossp`| Sole relevant function `uuid_generate_v4()` is superseded by core `gen_random_uuid()` (PostgreSQL >= 13). Enabling it would add a legacy function set with no benefit. |

## Consequences

- UUID defaults use core `gen_random_uuid()`; minimum PostgreSQL version is 13
  (see root `README.md`).
- Enabling `pg_trgm` at the foundation stage costs nothing at rest and avoids an
  online extension install during the search milestone.
- No other extension (PostGIS, Timescale, etc.) is needed by the approved
  architecture.
