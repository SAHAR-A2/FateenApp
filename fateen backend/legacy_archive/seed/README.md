# Seed

Versioned seed data, idempotent by design (safety of re-run).

| Folder          | Content                                            | Phase |
| --------------- | -------------------------------------------------- | ----- |
| `00-system/`    | Bootstrapping data the schema depends on           | 8     |
| `01-reference/` | Governance / lookup / vocabulary reference data    | 8     |
| `02-demo/`      | Non-production demo datasets                       | 8     |

System and reference seeds are production data. Demo seeds are dev/test only.

`00-system/01_lifecycle_statuses.sql` is written and ships as migration `0007`
(Foundation Layer, `ADR-008`). The remaining system/reference/demo seeds arrive
with the Phase 8 seed milestone.
