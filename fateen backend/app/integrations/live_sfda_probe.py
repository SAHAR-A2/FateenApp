"""One live SFDA Food request by barcode (verification probe).

Runs ONLY when a completed credential path is configured (env / .env):
  - OAuth2: SFDA_CONSUMER_KEY + SFDA_CONSUMER_SECRET + SFDA_OAUTH_TOKEN_URL
  - or pre-minted bearer: SFDA_ACCESS_TOKEN

It NEVER ingests into FateenDB, NEVER migrates, NEVER changes schema, and
NEVER starts a batch. It prints the HTTP status, whether auth succeeded, the
response shape/field names, and whether barcode/product/ingredients came back.

If the OAuth token URL is not configured, this raises SfdaAuthenticationRequired
(NO_TOKEN_URL) BEFORE any network call - the exact missing-endpoint stop gate.

Usage:
    python -m app.integrations.live_sfda_probe --barcode 50254156
"""
import argparse
import sys

from app.core.config import settings


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--barcode", default="50254156", help="EAN / SFDA barcode to look up")
    args = parser.parse_args(argv)

    from app.integrations.sfda_food_adapter import (
        SfdaFoodAdapter,
        SfdaProductRecord,
    )

    token = (settings.sfda_access_token or "").strip()
    consumer_key = (settings.sfda_consumer_key or "").strip()
    consumer_secret = (settings.sfda_consumer_secret or "").strip()
    token_url = (settings.sfda_oauth_token_url or "").strip()

    mechanism = "pre-minted bearer (SFDA_ACCESS_TOKEN)" if token else (
        "OAuth2 client credentials (SFDA_OAUTH_TOKEN_URL)" if token_url else "NONE"
    )

    if not token and not (consumer_key and consumer_secret and token_url):
        print(f"ERROR: no completed SFDA credential path. mechanism present = {mechanism}")
        if token_url:
            if not consumer_key or not consumer_secret:
                print("  ERROR: SFDA_CONSUMER_KEY and SFDA_CONSUMER_SECRET must both be set "
                      "to use the OAuth path.")
        else:
            print("  STOP: the OAuth2 client_credentials token endpoint is required but is not "
                  "configured (SFDA_OAUTH_TOKEN_URL). The exact token URL must come from the "
                  "developer portal's Authentication/Tokens documentation - it is NOT guessed. "
                  "No network call was attempted.")
        return 1

    adapter = SfdaFoodAdapter(
        token=token or None,
        consumer_key=consumer_key or None,
        consumer_secret=consumer_secret or None,
        oauth_token_url=token_url or None,
    )

    try:
        record: SfdaProductRecord = adapter.fetch_by_barcode(args.barcode)
    except Exception as exc:  # report the typed fault without ever printing secrets
        from app.integrations.sfda_food_adapter import SfdaHttpError, SfdaUnreachable

        if isinstance(exc, SfdaHttpError):
            print(f"HTTP STATUS  : {exc.status_code}")
            print(f"AUTH SUCCEED : False (HTTP error; code={exc.code})")
            print(f"response     : no product envelope (auth or route rejected)")
            return 2
        if isinstance(exc, SfdaUnreachable):
            print("HTTP STATUS  : unreachable")
            print(f"AUTH SUCCEED : False ({exc.code})")
            print("response     : no HTTP response received")
            return 3
        print(f"ERROR (type={type(exc).__name__}): {exc}")
        return 4

    payload = record.raw_payload or {}
    print("HTTP STATUS  : 200 (2xx accepted)")
    print("AUTH SUCCEED : True")
    print("RESPONSE SHAPE / FIELD NAMES:")
    print(f"   envelope keys   : {sorted(payload.keys())}")
    mapped = {
        "barcode": record.barcode,
        "trade_name": record.trade_name,
        "brand": record.brand,
        "company": record.company,
        "referanceNumber": record.source_record_id,
        "item_description": record.item_description,
        "ingredientsAr": record.ingredients_ar,
        "ingredientsEn": record.ingredients_en,
    }
    print(f"BARCODE       : {mapped['barcode']}")
    print(f"TRADE NAME    : {mapped['trade_name']}")
    print(f"BRAND         : {mapped['brand']}")
    print(f"COMPANY       : {mapped['company']}")
    print(f"REFERENCE #   : {mapped['referanceNumber']}")
    print(f"ITEM DESC     : {mapped['item_description']}")
    print("RETURNED DATA :")
    print(f"   barcode            returned : {bool(mapped['barcode'])}")
    print(f"   product             returned : {bool(mapped['trade_name'] or mapped['brand'] or mapped['company'])}")
    print(f"   ingredients (ar)    returned : {bool(mapped['ingredientsAr'])}")
    print(f"   ingredients (en)    returned : {bool(mapped['ingredientsEn'])}")
    print("NOTE: probe only. NOT ingested into FateenDB; no migration; no schema change; no batch.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())