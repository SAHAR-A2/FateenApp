"""SFDA production-scale batch ingestion path (auth-independent).

Builds the full SFDA pipeline so that the moment a credential is configured
(SFDA_ACCESS_TOKEN bearer or SFDA_API_KEY FIRS key) the 10 -> 100 -> 250 ->
500 -> ~1,000 product batches can run without redesign:

    candidates -> fetch -> normalize -> resolve -> validate -> insert/quarantine

Everything in this package is designed to work TODAY without live SFDA auth:

  * `--dry-run` and fixture fetchers exercise the whole pipeline offline.
  * Checkpointing, retries, rate limiting and quarantine are file-backed
    (no database migration required - STEP A rule).
  * Quarantine uses existing conventions and falls back to a file sink when the
    proposed DB table (migrations/0047_*, unapplied) is absent.
  * Live mode is gated by a credential preflight that raises the SAME
    SfdaAuthenticationRequired (NO_TOKEN/NO_API_KEY) before any network call,
    so no authentication bypass is possible.

The live 10-product proof and all scaling gates then execute as a single
reproducible command (see app.batch.cli).
"""