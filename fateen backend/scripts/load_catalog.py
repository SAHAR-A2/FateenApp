#!/usr/bin/env python3
"""Load reviewed products from a catalog manifest into FateenDB.

Usage (from the backend root):
    python scripts/load_catalog.py MANIFEST.json [--database-url URL]                  # preview
    python scripts/load_catalog.py MANIFEST.json --apply --database-url URL

The manifest is built offline from the sources (see docs/CATALOG_LOADING.md)
and lists one product per entry:

    {"barcode": "6281007031585",            # valid GTIN, required
     "name_ar": "...", "name_ar_status": "approved" | "pending_review",
     "name_en": "...", "name_en_status": "approved" | "pending_review",
     "description_ar": "...", "description_en": "...",          # optional
     "brand": "Almarai", "company": "Almarai",                  # optional
     "category": "DAIRY",                                       # product_categories.code
     "image": {"url": "...", "sha256": "...", "mime": "image/webp", "bytes": 12345},
     "nutrition": [{"type": "SUGAR", "amount": 10.1, "unit": "G", "basis": "PER_100ML"}],
     "ingredients": {"ar": "...", "en": "..."},                  # as printed, optional
     "allergens": {"MILK": "CONTAINS", "TREE_NUTS": "MAY_CONTAIN"},
     "source": "ALMARAI_WEBSITE" | "OPEN_FOOD_FACTS", "source_url": "...",
     "confidence": 0.9}

Rules:
  * A new barcode creates the product with everything in the entry. The base
    name (products.name) is the Arabic name.
  * An existing barcode is only completed: a missing translation, image,
    category, ingredient statement, allergen or nutrition set is added.
    Nothing already stored is changed; a differing value is reported.
    The one exception is --correct-categories FILE (barcode -> category,
    reviewed by hand): a listed product whose stored category differs is
    moved to the reviewed one.
  * Each product is written in its own savepoint, so one bad entry is
    reported and skipped without losing the others.
  * Allergens found in an ingredient statement (app.catalog.allergen_detection)
    are always added to the entry's own list: the allergy check trusts a
    statement as evidence.
  * Entries are written in batches (--batch, default 25), one transaction
    each. Preview (the default) rolls every batch back; --apply commits it.
    A dropped connection is reopened and the batch retried, and a stopped
    run can be started again: loaded barcodes come back "unchanged".
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from collections import Counter
from pathlib import Path

import psycopg
from psycopg.rows import dict_row

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from app.catalog.allergen_detection import detect, is_plausible_statement, merge  # noqa: E402
from app.core.gtin import has_valid_check_digit  # noqa: E402

_BARCODE_TYPE = {8: "EAN8", 12: "UPC_A", 13: "EAN13", 14: "GTIN"}
_STATUSES = {"approved", "pending_review"}


class Refs:
    """Reference ids looked up once by code."""

    def __init__(self, conn):
        def by_code(table, key="code"):
            return {str(r[key]).upper(): r["id"] for r in conn.execute(
                f"SELECT id, {key} FROM public.{table} WHERE deleted_at IS NULL")}

        self.active = conn.execute("SELECT id FROM public.lifecycle_statuses WHERE code = 'ACTIVE'").fetchone()["id"]
        self.languages = by_code("languages")
        self.relationships = by_code("relationship_types")
        self.evidence = by_code("evidence_types")
        self.verification = by_code("verification_statuses")
        self.barcode_types = by_code("barcode_types")
        self.nutrition_types = by_code("nutrition_types")
        self.units = by_code("units")
        self.bases = by_code("measurement_bases")
        self.allergens = by_code("allergens", "internal_code")
        self.categories = by_code("product_categories")
        self.image_types = by_code("image_types")
        self.sources = by_code("data_sources")
        missing = [name for name, table, code in (
            ("image type FRONT", self.image_types, "FRONT"),
            ("relationship PRIMARY_IMAGE", self.relationships, "PRIMARY_IMAGE"),
            ("data source ALMARAI_WEBSITE", self.sources, "ALMARAI_WEBSITE"),
            ("allergen GLUTEN", self.allergens, "GLUTEN"),
        ) if code not in table]
        if missing:
            raise SystemExit(f"Apply migrations 0055 and 0056 first; missing: {', '.join(missing)}")


def validate(entry: dict, refs: Refs) -> list[str]:
    """Reasons the entry cannot be loaded (empty when it is fine)."""
    problems = []
    barcode = str(entry.get("barcode") or "")
    if not (barcode.isdigit() and len(barcode) in _BARCODE_TYPE and has_valid_check_digit(barcode)):
        problems.append("barcode is not a valid GTIN")
    if not (entry.get("name_ar") or "").strip():
        problems.append("no Arabic name")
    for lang in ("ar", "en"):
        if entry.get(f"name_{lang}") and entry.get(f"name_{lang}_status") not in _STATUSES:
            problems.append(f"name_{lang}_status must be approved or pending_review")
    if entry.get("category") and entry["category"].upper() not in refs.categories:
        problems.append(f"unknown category {entry['category']}")
    if entry.get("source", "").upper() not in refs.sources:
        problems.append(f"unknown source {entry.get('source')}")
    for n in entry.get("nutrition") or []:
        if n["type"].upper() not in refs.nutrition_types:
            problems.append(f"unknown nutrition type {n['type']}")
        if n["unit"].upper() not in refs.units or n["basis"].upper() not in refs.bases:
            problems.append(f"unknown unit/basis {n['unit']}/{n['basis']}")
        if not isinstance(n["amount"], (int, float)) or n["amount"] < 0:
            problems.append(f"bad amount for {n['type']}")
    for code, relation in (entry.get("allergens") or {}).items():
        if code.upper() not in refs.allergens:
            problems.append(f"unknown allergen {code}")
        if relation not in ("CONTAINS", "MAY_CONTAIN"):
            problems.append(f"bad allergen relation {relation}")
    image = entry.get("image")
    if image and not (image.get("url", "").startswith("https://") and re.fullmatch(r"[0-9a-f]{64}", image.get("sha256", ""))):
        problems.append("image needs an https url and a sha256")
    return problems


def _find_product(conn, barcode: str):
    return conn.execute(
        """
        SELECT p.id, p.product_category_id
        FROM public.product_barcodes pb
        JOIN public.barcodes b ON b.id = pb.barcode_id
        JOIN public.products p ON p.id = pb.product_id
        WHERE b.barcode = %s AND pb.deleted_at IS NULL AND b.deleted_at IS NULL
          AND p.deleted_at IS NULL
          AND (pb.effective_to IS NULL OR pb.effective_to > NOW())
        LIMIT 1
        """,
        (barcode,),
    ).fetchone()


def _existing(conn, product_id) -> dict:
    one = lambda sql: conn.execute(sql, (product_id,)).fetchall()  # noqa: E731
    return {
        "languages": {r["code"] for r in one(
            """SELECT l.code FROM public.product_translations t JOIN public.languages l ON l.id = t.language_id
               WHERE t.product_id = %s AND t.deleted_at IS NULL AND t.translation_status <> 'rejected'""")},
        "has_image": bool(one("SELECT 1 FROM public.product_images WHERE product_id = %s AND deleted_at IS NULL")),
        "allergens": {str(r["internal_code"]).upper() for r in one(
            """SELECT a.internal_code FROM public.product_allergens pa JOIN public.allergens a ON a.id = pa.allergen_id
               WHERE pa.product_id = %s AND pa.deleted_at IS NULL""")},
        "has_nutrition": bool(one("SELECT 1 FROM public.product_nutrition_values WHERE product_id = %s AND deleted_at IS NULL")),
        "statements": {r["language_code"] for r in one(
            "SELECT language_code FROM public.product_ingredient_statements WHERE product_id = %s AND deleted_at IS NULL")},
    }


def _code(prefix: str, name: str) -> str:
    return prefix + "_" + re.sub(r"[^A-Z0-9]+", "_", name.upper()).strip("_")


def _brand_id(conn, refs: Refs, entry: dict, source_id):
    brand = (entry.get("brand") or "").strip()
    if not brand:
        return None
    company = (entry.get("company") or brand).strip()
    row = conn.execute("SELECT id FROM public.companies WHERE lower(name) = lower(%s) AND deleted_at IS NULL", (company,)).fetchone()
    company_id = row["id"] if row else conn.execute(
        """INSERT INTO public.companies (internal_code, name, status_id, source_id, confidence_level, country)
           VALUES (%s, %s, %s, %s, %s, 'SA') RETURNING id""",
        (_code("COMPANY", company), company, refs.active, source_id, entry.get("confidence", 0.5)),
    ).fetchone()["id"]
    row = conn.execute(
        "SELECT id FROM public.brands WHERE lower(name) = lower(%s) AND company_id = %s AND deleted_at IS NULL",
        (brand, company_id)).fetchone()
    return row["id"] if row else conn.execute(
        """INSERT INTO public.brands (company_id, internal_code, name, status_id, source_id, confidence_level)
           VALUES (%s, %s, %s, %s, %s, %s) RETURNING id""",
        (company_id, _code("BRAND", brand), brand, refs.active, source_id, entry.get("confidence", 0.5)),
    ).fetchone()["id"]


def load_entry(conn, refs: Refs, entry: dict, corrected_category: str | None = None) -> dict:
    """Write one entry. Returns {"action": "created"|"completed"|"unchanged", "added": [...]}."""
    source_id = refs.sources[entry["source"].upper()]
    evidence_id = refs.evidence.get("MANUFACTURER" if entry["source"].upper() == "ALMARAI_WEBSITE" else "DATABASE")
    confidence = float(entry.get("confidence", 0.5))
    barcode = str(entry["barcode"])
    added: list[str] = []

    found = _find_product(conn, barcode)
    if found is None:
        product_id = conn.execute(
            """INSERT INTO public.products (brand_id, product_category_id, internal_code, name, description,
                                            status_id, source_id, confidence_level)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id""",
            (_brand_id(conn, refs, entry, source_id),
             refs.categories.get((entry.get("category") or "").upper()),
             f"FATEEN_{barcode}", entry["name_ar"].strip(), entry.get("description_ar"),
             refs.active, source_id, confidence),
        ).fetchone()["id"]
        barcode_row = conn.execute("SELECT id FROM public.barcodes WHERE barcode = %s AND deleted_at IS NULL",
                                   (barcode,)).fetchone()
        barcode_id = barcode_row["id"] if barcode_row else conn.execute(
            """INSERT INTO public.barcodes (barcode, barcode_type_id, verification_status_id, source_id,
                                            status_id, confidence_level)
               VALUES (%s, %s, %s, %s, %s, %s) RETURNING id""",
            (barcode, refs.barcode_types[_BARCODE_TYPE[len(barcode)]], refs.verification["UNVERIFIED"],
             source_id, refs.active, confidence),
        ).fetchone()["id"]
        conn.execute(
            """INSERT INTO public.product_barcodes (product_id, barcode_id, relationship_type_id, source_id,
                                                    evidence_type_id, confidence_level, status_id)
               VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            (product_id, barcode_id, refs.relationships["PRIMARY_BARCODE"], source_id, evidence_id,
             confidence, refs.active),
        )
        existing = {"languages": set(), "has_image": False, "allergens": set(),
                    "has_nutrition": False, "statements": set()}
        action = "created"
    else:
        product_id = found["id"]
        existing = _existing(conn, product_id)
        action = "completed"
        if found["product_category_id"] is None and entry.get("category"):
            conn.execute("UPDATE public.products SET product_category_id = %s WHERE id = %s",
                         (refs.categories[entry["category"].upper()], product_id))
            added.append("category")
        elif corrected_category and found["product_category_id"] != refs.categories[corrected_category.upper()]:
            conn.execute("UPDATE public.products SET product_category_id = %s WHERE id = %s",
                         (refs.categories[corrected_category.upper()], product_id))
            added.append("category corrected")

    for lang in ("ar", "en"):
        name = (entry.get(f"name_{lang}") or "").strip()
        if name and lang not in existing["languages"]:
            conn.execute(
                """INSERT INTO public.product_translations (product_id, language_id, name, display_name,
                                                            search_name, description, translation_status)
                   VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (product_id, refs.languages[lang.upper()], name, name, name.lower(),
                 entry.get(f"description_{lang}"), entry[f"name_{lang}_status"]),
            )
            added.append(f"name_{lang}")

    image = entry.get("image")
    if image and not existing["has_image"]:
        # Sizes of one product share a photo, and images.content_hash is
        # unique: reuse the stored image.
        same = conn.execute("SELECT id FROM public.images WHERE content_hash = %s AND deleted_at IS NULL",
                            (image["sha256"],)).fetchone()
        image_id = same["id"] if same else conn.execute(
            """INSERT INTO public.images (image_type_id, source_id, storage_uri, content_hash, mime_type,
                                          file_size, status_id, metadata)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s) RETURNING id""",
            (refs.image_types["FRONT"], source_id, image["url"], image["sha256"],
             image.get("mime") or "image/jpeg", int(image.get("bytes") or 0), refs.active,
             json.dumps({"source_url": entry.get("source_url")})),
        ).fetchone()["id"]
        conn.execute(
            """INSERT INTO public.product_images (product_id, image_id, relationship_type_id, source_id,
                                                  evidence_type_id, confidence_level, status_id)
               VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            (product_id, image_id, refs.relationships["PRIMARY_IMAGE"], source_id, evidence_id,
             confidence, refs.active),
        )
        added.append("image")

    for lang, statement in (entry.get("ingredients") or {}).items():
        if (lang in ("ar", "en") and is_plausible_statement(statement or "")
                and lang not in existing["statements"]):
            conn.execute(
                """INSERT INTO public.product_ingredient_statements (product_id, language_code, statement,
                                                                     source_id, source_url)
                   VALUES (%s, %s, %s, %s, %s)""",
                (product_id, lang, statement.strip(), source_id, entry.get("source_url")),
            )
            added.append(f"ingredients_{lang}")

    # The allergy check treats an ingredient statement as evidence, so the
    # allergens found in it are always stored with it, whatever the manifest
    # says.
    allergens = merge(entry.get("allergens") or {},
                      *(detect(t) for t in (entry.get("ingredients") or {}).values() if is_plausible_statement(t or "")))
    # Only allergens not yet recorded for the product are added; existing
    # rows are never changed.
    new_allergens = {c: r for c, r in allergens.items() if c.upper() not in existing["allergens"]}
    if new_allergens:
        for code, relation in sorted(new_allergens.items()):
            conn.execute(
                """INSERT INTO public.product_allergens (product_id, allergen_id, relationship_type_id, source_id,
                                                         evidence_type_id, confidence_level, status_id)
                   VALUES (%s, %s, %s, %s, %s, %s, %s)""",
                (product_id, refs.allergens[code.upper()],
                 refs.relationships["CONTAINS_ALLERGEN" if relation == "CONTAINS" else "MAY_CONTAIN_ALLERGEN"],
                 source_id, evidence_id, confidence, refs.active),
            )
        added.append("allergens")

    nutrition = entry.get("nutrition") or []
    if nutrition and not existing["has_nutrition"]:
        for n in nutrition:
            conn.execute(
                """INSERT INTO public.product_nutrition_values (product_id, nutrition_type_id, relationship_type_id,
                                                                amount_value, unit_id, source_id, evidence_type_id,
                                                                confidence_level, status_id, measurement_basis_id)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (product_id, refs.nutrition_types[n["type"].upper()], refs.relationships["MEASURED_VALUE"],
                 n["amount"], refs.units[n["unit"].upper()], source_id, evidence_id, confidence,
                 refs.active, refs.bases[n["basis"].upper()]),
            )
        added.append("nutrition")

    if action == "completed" and not added:
        action = "unchanged"
    return {"action": action, "added": added}


APP_NAME = "fateen_catalog_loader"


def _connect(url: str):
    # Keepalives stop a NAT or pooler from dropping a connection that waits
    # on a long batch. A short lock_timeout makes a batch that waits on a
    # stale session fail fast and be retried instead of hanging.
    conn = psycopg.connect(url, row_factory=dict_row, connect_timeout=30, application_name=APP_NAME,
                           keepalives=1, keepalives_idle=30, keepalives_interval=10, keepalives_count=5)
    conn.execute("SET lock_timeout = '20s'")
    _end_stale_sessions(conn)
    conn.commit()
    return conn


def _end_stale_sessions(conn) -> None:
    """End this loader's own earlier sessions that are still open on the
    server after the client lost its network: their open transaction holds
    locks on the rows the retried batch writes. Only sessions named
    fateen_catalog_loader are touched; if the role may not end them, the
    batch simply waits for the server to drop them."""
    try:
        ended = conn.execute(
            """
            SELECT pg_terminate_backend(pid) AS ended
            FROM pg_stat_activity
            WHERE application_name = %s AND pid <> pg_backend_pid()
              AND state LIKE 'idle in transaction%%'
            """,
            (APP_NAME,),
        ).fetchall()
        if ended:
            print(f"  ended {len(ended)} stale loader session(s)", flush=True)
    except psycopg.Error:
        conn.rollback()


def _reconnect(url: str, tries: int = 8):
    """Reopen the connection, waiting out a short network outage (a lost
    route or DNS lookup fails too, not just the socket)."""
    for attempt in range(tries):
        time.sleep(min(60, 5 * (attempt + 1)))
        try:
            return _connect(url)
        except psycopg.OperationalError as exc:
            print(f"  cannot reconnect yet: {str(exc).splitlines()[0]}", flush=True)
    raise SystemExit("Could not reconnect to the database. Check the network and run the same command again.")


def _run_batch(conn, refs: Refs, batch: list[dict], corrections: dict | None = None) -> list[dict]:
    results = []
    for entry in batch:
        problems = validate(entry, refs)
        if problems:
            results.append({"barcode": entry.get("barcode"), "action": "rejected", "problems": problems})
            continue
        try:
            with conn.transaction():
                result = load_entry(conn, refs, entry, (corrections or {}).get(str(entry["barcode"])))
        except psycopg.OperationalError:
            raise  # the connection is gone: retry the whole batch
        except psycopg.Error as exc:
            result = {"action": "failed", "error": str(exc).splitlines()[0]}
        results.append({"barcode": entry["barcode"], **result})
    return results


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("manifest")
    parser.add_argument("--database-url")
    parser.add_argument("--apply", action="store_true", help="commit (default: preview, rolled back)")
    parser.add_argument("--batch", type=int, default=25, help="entries per transaction (default 25)")
    parser.add_argument("--report", help="per-product JSON report (default: <manifest>.report.json)")
    parser.add_argument("--correct-categories", metavar="FILE",
                        help="barcode -> category reviewed by hand; moves listed products whose stored category differs")
    args = parser.parse_args(argv)

    if args.apply and not args.database_url:
        raise SystemExit("--apply needs an explicit --database-url")
    url = args.database_url or os.environ.get("CLOUD_DATABASE_URL") or os.environ.get("DATABASE_URL")
    if not url:
        raise SystemExit("No database URL: pass --database-url or set CLOUD_DATABASE_URL")
    entries = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    report_path = Path(args.report or f"{args.manifest}.report.json")
    corrections = (json.loads(Path(args.correct_categories).read_text(encoding="utf-8"))
                   if args.correct_categories else None)

    # Each batch is its own transaction: committed with --apply, rolled back
    # in a preview. A dropped connection is reopened and the batch retried;
    # a batch never half-commits, and loading is idempotent, so a run that
    # stops can simply be started again.
    report, counts = [], Counter()
    conn = _connect(url)
    try:
        print(f"Database: {conn.info.user}@{conn.info.host}/{conn.info.dbname}", flush=True)
        refs = Refs(conn)
        conn.commit()  # end the read-only lookup transaction
        for start in range(0, len(entries), args.batch):
            batch = entries[start:start + args.batch]
            for attempt in range(4):
                try:
                    # The outer transaction makes each entry's own
                    # transaction a savepoint; a preview forces it to roll
                    # back, so nothing of the batch is ever committed.
                    with conn.transaction(force_rollback=not args.apply):
                        results = _run_batch(conn, refs, batch, corrections)
                    break
                except psycopg.OperationalError as exc:
                    if attempt == 3:
                        raise SystemExit(
                            f"Connection lost 4 times at entries {start + 1}-{start + len(batch)}: "
                            f"{str(exc).splitlines()[0]}. Entries before {start + 1} are "
                            + ("committed; run the same command again to continue." if args.apply
                               else "checked; nothing was written.")
                        )
                    print(f"  connection lost, reconnecting (attempt {attempt + 2}/4)", flush=True)
                    try:
                        conn.close()
                    except psycopg.Error:
                        pass
                    conn = _reconnect(url)
            report.extend(results)
            counts.update(r["action"] for r in results)
            report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"  {min(start + args.batch, len(entries))}/{len(entries)}  {dict(counts)}", flush=True)
    finally:
        conn.close()

    print(f"Entries: {len(entries)}  {dict(counts)}")
    print(f"Per-product report: {report_path}")
    print("Committed." if args.apply else "Preview only, rolled back. Add --apply --database-url URL to write.")
    return 1 if counts["failed"] else 0


if __name__ == "__main__":
    sys.exit(main())
