# Docs

Master documentation for the Fateen database.

| Folder             | Purpose                                                     |
| ------------------ | ----------------------------------------------------------- |
| `01-entity-list/`  | Phase 2 — complete entity inventory                         |
| `02-erd/`          | Phase 3 — ERD planning, diagrams, relationship matrix       |
| `03-conventions/`  | Naming, typing, indexing, and style conventions             |
| `04-decisions/`    | Architecture / design decision records (ADR)                |

Mission reports: `mission03_report.md` documents the Canonical Core Entities
(Mission 03), `mission04_report.md` the Relationship & Junction Tables
(Mission 04), `mission05_report.md` the Version History & Audit
Infrastructure (Mission 05), `mission07_report.md` the Canonical Media &
Barcode Domain (Mission 07), `mission08_report.md` the Search Layer
(Derived Read Models, Mission 08), and `mission09_report.md` the Database
Foundation Finalization & Certification (Mission 09, certification-only).
`ecr001_report.md` documents ECR-001, the additive closure of the five
remaining certification blockers (product↔media relationships, relationship
endpoint validation, automatic history capture, and the nutrition
measurement-basis dimension; migrations `0032`–`0037`).
`database_certification_report.md` is the repository-wide verification and
consistency audit; `architecture_summary.md` is the schema quality report and
performance review. `ecr002_report.md` is the **final production-readiness
certification** (ECR-002) of the complete chain `0001`–`0037`, including the
deployment plan, post-deployment sanity checks, stress review, readiness
scores, and the Phase 2 GO/NO-GO answer.
`open_questions.md` records reference domains intentionally
not built and their open decisions.

Phase 9 consolidates these into the final database manual.
