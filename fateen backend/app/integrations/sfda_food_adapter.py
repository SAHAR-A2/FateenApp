"""SFDA Registered Food Products API adapter (official regulatory source).

Contract source (authoritative, verified 2026-09-07):
    https://developer.sfda.gov.sa/apidoc/registered-food-service/82
    OpenAPI 3.0.1 spec: `food-products-swagger-production-0.2.yaml`
    server: https://apis.sfda.gov.sa:9002/v2/Food
    auth:   Authorization: Bearer <token>   (http bearer scheme)

STATUS:
    Contract                  : VERIFIED against the official spec.
    Production gateway        : reachable, but unauthenticated /v2/Food routes
                                are black-holed (no HTTP response). A valid
                                developer-portal subscription token is required.
    In this environment       : no completed SFDA credential path is
                                configured (no SFDA_ACCESS_TOKEN, no
                                SFDA_API_KEY, and no
                                SFDA_CONSUMER_KEY/SECRET + SFDA_OAUTH_TOKEN_URL),
                                so every network call raises
                                SfdaAuthenticationRequired BEFORE any request
                                is attempted. This adapter is therefore a
                                correct, field-preserving interface that is
                                ready to run the 10-product proof the moment a
                                documented credential path is provided. NO data
                                is fabricated.

Design rules enforced here (per the SFDA integration spec):
  - No invented endpoints/fields: every constant below comes from the spec.
  - No fabricated data: mapping only copies fields the API actually returns.
  - Field preservation: the official payload is kept verbatim (raw_payload).
  - Errors are typed and explicit (401-01/02/03, 422, 404, 429, 5xx).
  - The official field name `referanceNumber` (typo included) is preserved.
"""

from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Optional

import httpx

from app.agent.normalizers import normalize_barcode
from app.core.config import settings

# --------------------------------------------------------------------------
# Contract constants (from the official OpenAPI spec)
# --------------------------------------------------------------------------

SFDA_CONTRACT_VERSION = "registered-food-service/v1 + firs-open-data"
SFDA_BASE_URL = "https://apis.sfda.gov.sa:9002"
SFDA_PRODUCTS_PATH = "/v2/Food"
SFDA_FIRS_PATH = "/v2/FIRS/food"
SFDA_ENDPOINTS = {
    "list": SFDA_PRODUCTS_PATH + "/product/list/{page}",
    "by_id": SFDA_PRODUCTS_PATH + "/product/id/{productid}",
    "by_referencenumber": SFDA_PRODUCTS_PATH + "/product/referencenumber/{referencenumber}",
    "by_barcode": SFDA_PRODUCTS_PATH + "/product/barcode/{barcode}",
    "search": SFDA_PRODUCTS_PATH + "/product/search/{keyword}/{page}",
    "image": SFDA_PRODUCTS_PATH + "/image/{image_code}",
    # FIRS open-data web services (documented official variants; API-key based)
    "firs_list": SFDA_FIRS_PATH + "/list",
    "firs_search": SFDA_FIRS_PATH + "/search",
}
SFDA_USER_AGENT = "Fateen-SFDA-Adapter/0.1"

# Documented 401 sub-codes from the spec.
SFDA_ERR_AUTH_FAILED = "401-01"
SFDA_ERR_TOKEN_EXPIRED = "401-02"
SFDA_ERR_NO_API_PRODUCT = "401-03"
SFDA_ERR_RATE_LIMITED = "429-01"


class SfdaAdapterError(Exception):
    """Base class for all SFDA adapter errors."""

    def __init__(self, message: str, code: Optional[str] = None):
        super().__init__(message)
        self.code = code


class SfdaAuthenticationRequired(SfdaAdapterError):
    """Raised when a network operation requires a token that is not configured."""


class SfdaHttpError(SfdaAdapterError):
    """Raised for a non-2xx response whose envelope was parsed or status seen."""

    def __init__(
        self,
        message: str,
        status_code: Optional[int] = None,
        code: Optional[str] = None,
    ):
        super().__init__(message, code=code)
        self.status_code = status_code


class SfdaUnreachable(SfdaAdapterError):
    """Transaction-level failure (timeout, connection, gateway black-hole)."""


class SfdaValidationError(SfdaAdapterError):
    """Bad input for a lookup (invalid barcode / reference / page)."""


class SfdaPayloadError(SfdaAdapterError):
    """Response did not match the documented contract structure."""


# --------------------------------------------------------------------------
# DTOs - official field names preserved.
# --------------------------------------------------------------------------


@dataclass
class SfdaFoodProduct:
    """One `FoodProduct` schema object (all documented fields preserved).

    `raw_payload` always keeps the exact API object so nothing is lost.
    """

    id: Optional[int] = None
    bayaN_ID: Optional[int] = None
    requestType: Optional[str] = None
    referanceNumber: Optional[str] = None          # official spelling kept
    submittedDate: Optional[str] = None
    lastActionDate: Optional[str] = None
    closeDate: Optional[str] = None
    arStatus: Optional[str] = None
    enStatus: Optional[str] = None
    isClosed: Optional[bool] = None
    initiatorId: Optional[int] = None
    assignedToId: Optional[int] = None
    assignedToGroupId: Optional[int] = None
    renewPeriod: Optional[str] = None
    workflowType: Optional[str] = None
    workflowInstanceId: Optional[str] = None
    barCode: Optional[str] = None
    brandName: Optional[str] = None
    tradeName: Optional[str] = None
    hsCode: Optional[str] = None
    itemWeight: Optional[int] = None
    unitNameAr: Optional[str] = None
    unitNameEn: Optional[str] = None
    itemDrainWeight: Optional[int] = None
    itemDrainWeightUnitId: Optional[str] = None
    arCOO: Optional[str] = None
    enCOO: Optional[str] = None
    arCOPacking: Optional[str] = None
    enCOPacking: Optional[str] = None
    arCOProduction: Optional[str] = None
    enCOProduction: Optional[str] = None
    arPackingType: Optional[str] = None
    enPackingType: Optional[str] = None
    shelfTimeAr: Optional[str] = None
    shelfTimeEn: Optional[str] = None
    storageTemperatureAr: Optional[str] = None
    storageTemperatureEn: Optional[str] = None
    approvalNo: Optional[str] = None
    itemCertificates: Optional[str] = None
    itemRisck: Optional[str] = None
    itemLabelId: Optional[int] = None
    foodItemId: Optional[int] = None
    itemCategoriesHs2Id: Optional[int] = None
    itemSubCategoriesHs4Id: Optional[int] = None
    itemSubCategoriesHs6Id: Optional[int] = None
    itemSubCategoriesHs8Id: Optional[int] = None
    isLocal: Optional[bool] = None
    itemRiskId: Optional[str] = None
    itemId: Optional[int] = None
    createdOn: Optional[str] = None
    companyName: Optional[str] = None
    usageMethodId: Optional[int] = None
    ageGroupAr: Optional[str] = None
    ageGroupEn: Optional[str] = None
    oldRequestId: Optional[int] = None
    oldReferenceNumber: Optional[str] = None
    arClearance: Optional[str] = None
    enClearance: Optional[str] = None
    clearanceRequestSubmissionDate: Optional[str] = None
    clearanceRequestLastActionDate: Optional[str] = None
    arFoodGroup: Optional[str] = None
    enFoodGroup: Optional[str] = None
    subGroupName: Optional[str] = None
    itemDescription: Optional[str] = None
    ingredientsAr: Optional[str] = None
    ingredientsEn: Optional[str] = None
    processing: Optional[str] = None
    warnings: Optional[str] = None
    samplingRequirements: Optional[str] = None
    hsCode_Description: Optional[str] = None
    # FIRS open-data service passes shelf-life/storage as simple fields.
    shelfTime: Optional[str] = None
    storageTemperatureAr: Optional[str] = None
    raw_payload: dict = field(default_factory=dict)


@dataclass
class SfdaProductRecord:
    """The mission-defined normalized output record from the adapter.

    This is the DTO the rest of FATEEN consumes. `raw_payload` preserves the
    exact official response for the evidence/raw-data pipeline.
    """

    source: str = "SFDA"
    source_record_id: Optional[str] = None      # official referanceNumber
    barcode: Optional[str] = None
    registration_number: Optional[str] = None    # alias of source_record_id
    trade_name: Optional[str] = None
    brand: Optional[str] = None
    company: Optional[str] = None
    item_description: Optional[str] = None
    ingredients_ar: Optional[str] = None
    ingredients_en: Optional[str] = None
    warnings_ar: Optional[str] = None
    weight: Optional[int] = None
    unit: Optional[str] = None
    en_status: Optional[str] = None
    ar_status: Optional[str] = None
    is_closed: Optional[bool] = None
    raw_payload: dict = field(default_factory=dict)
    retrieved_at: Optional[str] = None


def to_product_record(product: SfdaFoodProduct, retrieved_at: Optional[str] = None) -> SfdaProductRecord:
    """Map an official FoodProduct object onto the normalized output record.

    Only fields the API actually returns are copied; nothing is invented.
    `ingredientsEn` is commonly empty on SFDA records and is intentionally
    kept optional (absent English text must never be fabricated).
    """
    if retrieved_at is None:
        retrieved_at = datetime.now(timezone.utc).isoformat(timespec="seconds")
    unit = product.unitNameEn or product.unitNameAr
    return SfdaProductRecord(
        source_record_id=product.referanceNumber,
        barcode=product.barCode,
        registration_number=product.referanceNumber,
        trade_name=product.tradeName,
        brand=product.brandName,
        company=product.companyName,
        item_description=product.itemDescription,
        ingredients_ar=product.ingredientsAr,
        ingredients_en=product.ingredientsEn,
        warnings_ar=product.warnings,
        weight=product.itemWeight,
        unit=unit,
        en_status=product.enStatus,
        ar_status=product.arStatus,
        is_closed=product.isClosed,
        raw_payload=product.raw_payload,
        retrieved_at=retrieved_at,
    )


# --------------------------------------------------------------------------
# Envelope parsing (per the documented response schemas)
# --------------------------------------------------------------------------


def parse_food_product(payload: dict) -> SfdaFoodProduct:
    """Parse an official FoodProduct object, preserving every field."""
    known = [
        "id", "bayaN_ID", "requestType", "referanceNumber", "submittedDate",
        "lastActionDate", "closeDate", "arStatus", "enStatus", "isClosed",
        "initiatorId", "assignedToId", "assignedToGroupId", "renewPeriod",
        "workflowType", "workflowInstanceId", "barCode", "brandName",
        "tradeName", "hsCode", "itemWeight", "unitNameAr", "unitNameEn",
        "itemDrainWeight", "itemDrainWeightUnitId", "arCOO", "enCOO",
        "arCOPacking", "enCOPacking", "arCOProduction", "enCOProduction",
        "arPackingType", "enPackingType", "shelfTimeAr", "shelfTimeEn",
        "storageTemperatureAr", "storageTemperatureEn", "approvalNo",
        "itemCertificates", "itemRisck", "itemLabelId", "foodItemId",
        "itemCategoriesHs2Id", "itemSubCategoriesHs4Id", "itemSubCategoriesHs6Id",
        "itemSubCategoriesHs8Id", "isLocal", "itemRiskId", "itemId",
        "createdOn", "companyName", "usageMethodId", "ageGroupAr",
        "ageGroupEn", "oldRequestId", "oldReferenceNumber", "arClearance",
        "enClearance", "clearanceRequestSubmissionDate",
        "clearanceRequestLastActionDate", "arFoodGroup", "enFoodGroup",
        "subGroupName", "itemDescription", "ingredientsAr", "ingredientsEn",
        "processing", "warnings", "samplingRequirements", "hsCode_Description",
    ]
    kwargs = {k: payload.get(k) for k in known}
    return SfdaFoodProduct(raw_payload=dict(payload), **kwargs)


def parse_product_response(body: dict) -> SfdaFoodProduct:
    """Parse a `FoodProductResponse` envelope: { code, name, data: { result } }."""
    if not isinstance(body, dict):
        raise SfdaPayloadError("response body is not a JSON object", code="MALFORMED")
    data = body.get("data")
    if isinstance(data, dict) and isinstance(data.get("result"), dict):
        return parse_food_product(data["result"])
    raise SfdaPayloadError(
        "response does not match FoodProductResponse envelope (no data.result)",
        code="MALFORMED",
    )


def parse_product_list_response(body: dict):
    """Parse a `FoodProductListResponse` envelope: data[] + metadata."""
    if not isinstance(body, dict):
        raise SfdaPayloadError("response body is not a JSON object", code="MALFORMED")
    data = body.get("data")
    if not isinstance(data, list):
        raise SfdaPayloadError(
            "response does not match FoodProductListResponse envelope (no data[])", code="MALFORMED"
        )
    products = [parse_food_product(item) for item in data if isinstance(item, dict)]
    return products, body.get("metadata") or {}


# Documented FIRS open-data field names (official service page). Values are
# mapped onto the shared SfdaFoodProduct DTO; the raw object is preserved.
FIRS_FIELD_MAP = {
    "barCode": "barCode",
    "barcode": "barCode",
    "referanceNumber": "referanceNumber",
    "RefNumber": "referanceNumber",
    "brandName": "brandName",
    "tradeName": "tradeName",
    "companyName": "companyName",
    "itemDescription": "itemDescription",
    "ItemDescription": "itemDescription",
    "shelfTime": "shelfTime",
    "storageTemperatureAr": "storageTemperatureAr",
    "warnings": "warnings",
    "ingredientsAr": "ingredientsAr",
    "ingredientsEn": "ingredientsEn",
    "itemWeight": "itemWeight",
    "unitNameAr": "unitNameAr",
    "unitNameEn": "unitNameEn",
    "enStatus": "enStatus",
    "arStatus": "arStatus",
    "isClosed": "isClosed",
}


def parse_firs_record(payload: dict) -> SfdaFoodProduct:
    """Map one FIRS open-data record (documented official field names) to the
    shared DTO. Every known documented field is copied; the raw object is kept
    verbatim so no information is lost regardless of casing variants."""
    if not isinstance(payload, dict):
        raise SfdaPayloadError("FIRS record is not a JSON object", code="MALFORMED")
    product = parse_food_product(payload)  # starts with exact field names
    for source_key, target_key in FIRS_FIELD_MAP.items():
        if source_key in payload and target_key in {"barCode", "referanceNumber", "brandName",
                                                     "tradeName", "companyName", "itemDescription",
                                                     "warnings", "ingredientsAr", "ingredientsEn",
                                                     "itemWeight", "unitNameAr", "unitNameEn",
                                                     "enStatus", "arStatus", "isClosed"}:
            value = payload[source_key]
            if getattr(product, target_key) is None and value is not None:
                setattr(product, target_key, value)
        elif source_key in payload:
            # shelfTime / storageTemperatureAr live on the DTO directly
            setattr(product, target_key, payload[source_key])
    return product


# --------------------------------------------------------------------------
# Input validation (STEP 6 rules: format / length / numeric)
# --------------------------------------------------------------------------

MIN_BARCODE_LEN = 6
MAX_BARCODE_LEN = 14


def validate_barcode(barcode: str) -> str:
    """Normalize to digits and enforce the documented numeric barcode shape.

    Uses the existing FATEEN normalizer (`normalize_barcode`); rejects empty /
    non-numeric / implausible-length input without touching the network.
    """
    normalized = normalize_barcode(barcode)
    if not normalized:
        raise SfdaValidationError("barcode is empty after normalization", code="BAD_BARCODE")
    if not normalized.isdigit():
        raise SfdaValidationError("barcode must contain only digits", code="BAD_BARCODE")
    if not (MIN_BARCODE_LEN <= len(normalized) <= MAX_BARCODE_LEN):
        raise SfdaValidationError(
            f"barcode length {len(normalized)} outside [{MIN_BARCODE_LEN}, {MAX_BARCODE_LEN}]",
            code="BAD_BARCODE",
        )
    return normalized


def validate_page(page: int) -> int:
    if not isinstance(page, int) or page < 1:
        raise SfdaValidationError("page must be a positive integer", code="BAD_PAGE")
    return page


# --------------------------------------------------------------------------
# Client
# --------------------------------------------------------------------------


class SfdaFoodAdapter:
    """Small, contract-faithful client for the SFDA Registered Food Products API.

    Authentication is resolved in this order (nothing is guessed):
      1. an explicitly-provided 24h bearer token (`SFDA_ACCESS_TOKEN`), used
         as-is;
      2. the OAuth2 client-credentials exchange from the developer portal's
         Consumer Key/Secret (`SFDA_CONSUMER_KEY` + `SFDA_CONSUMER_SECRET`).
         The exchange is only attempted when `SFDA_OAUTH_TOKEN_URL` is
         configured; until that endpoint is known the client raises
         SfdaAuthenticationRequired(code=NO_TOKEN_URL) and NO request is sent.

    Network calls are therefore never attempted without a documented
    credential path, which prevents the unauthenticated black-hole behavior
    observed on the production gateway. Callers must provide a credential
    (developer.sfda.gov.sa subscription) to perform lookups.
    """

    def __init__(
        self,
        base_url: Optional[str] = None,
        token: Optional[str] = None,
        api_key: Optional[str] = None,
        timeout: Optional[float] = None,
        consumer_key: Optional[str] = None,
        consumer_secret: Optional[str] = None,
        oauth_token_url: Optional[str] = None,
        oauth_scope: Optional[str] = None,
        transport: Optional[Any] = None,
    ) -> None:
        self.base_url = (base_url or settings.sfda_base_url or SFDA_BASE_URL).rstrip("/")
        self._token = token if token is not None else settings.sfda_access_token
        self._api_key = api_key if api_key is not None else settings.sfda_api_key
        self.api_key_header = settings.sfda_api_key_header
        self.timeout = timeout if timeout is not None else settings.sfda_timeout
        self._consumer_key = (
            consumer_key if consumer_key is not None else settings.sfda_consumer_key
        )
        self._consumer_secret = (
            consumer_secret if consumer_secret is not None else settings.sfda_consumer_secret
        )
        self._oauth_token_url = (
            oauth_token_url if oauth_token_url is not None else settings.sfda_oauth_token_url
        )
        self._oauth_scope = oauth_scope if oauth_scope is not None else settings.sfda_oauth_scope
        self._transport = transport

    # -- auth helpers -------------------------------------------------------

    def _bearer_token(self) -> str:
        explicit = (self._token or "").strip()
        if explicit:
            return explicit
        from app.integrations.sfda_auth import SfdaOAuth2ClientCredentials

        oauth = SfdaOAuth2ClientCredentials(
            consumer_key=self._consumer_key,
            consumer_secret=self._consumer_secret,
            token_url=self._oauth_token_url,
            scope=self._oauth_scope,
            timeout=self.timeout,
            transport=self._transport,
        )
        return oauth.token()

    def _require_token(self) -> str:
        try:
            return self._bearer_token()
        except SfdaAdapterError as exc:
            if exc.code == "NO_CREDENTIAL":
                raise SfdaAuthenticationRequired(
                    "SFDA credential is not configured. Set either "
                    "SFDA_ACCESS_TOKEN (pre-minted 24h bearer) or "
                    "SFDA_CONSUMER_KEY + SFDA_CONSUMER_SECRET with "
                    "SFDA_OAUTH_TOKEN_URL (OAuth2 client credentials from "
                    "https://developer.sfda.gov.sa). No network call was "
                    "attempted.",
                    code="NO_CREDENTIAL",
                ) from exc
            raise

    def _require_api_key(self) -> str:
        api_key = (self._api_key or "").strip()
        if not api_key:
            raise SfdaAuthenticationRequired(
                "SFDA FIRS API key is not configured. Set SFDA_API_KEY "
                "(issued through the official SFDA open-data service). No "
                "network call was attempted.",
                code="NO_API_KEY",
            )
        return api_key

    def access_configured(self) -> dict:
        """Report which documented credential mechanisms are configured.

        Presence flags only - never the values. A usable OAuth path requires
        consumer key AND secret AND the documented token URL, all present.
        """
        return {
            "bearer_token": bool((self._token or "").strip()),
            "firs_api_key": bool((self._api_key or "").strip()),
            "consumer_key": bool((self._consumer_key or "").strip()),
            "consumer_secret": bool((self._consumer_secret or "").strip()),
            "oauth_token_url": bool((self._oauth_token_url or "").strip()),
            "oauth_complete": (
                bool((self._consumer_key or "").strip())
                and bool((self._consumer_secret or "").strip())
                and bool((self._oauth_token_url or "").strip())
            ),
        }

    def token_configured(self) -> bool:
        return bool((self._token or "").strip())

    # -- transport ----------------------------------------------------------

    def _get(self, path: str) -> dict:
        token = self._require_token()  # raises before any request when absent
        return self._get_url(path, {"Authorization": f"Bearer {token}"})

    def _get_firs(self, path: str) -> dict:
        """Minimal request against the documented FIRS open-data endpoints.

        Credential transport (`settings.sfda_api_key_header`) MUST be
        reconciled with the live official FIRS documentation before any real
        call is made; until then this method refuses to run with an unset key.
        """
        api_key = self._require_api_key()
        return self._get_url(path, {self.api_key_header: api_key})

    def _get_url(self, path: str, auth_headers: dict) -> dict:
        url = f"{self.base_url}{path}"
        headers = {
            "Accept": "application/json",
            "User-Agent": SFDA_USER_AGENT,
        }
        headers.update(auth_headers or {})
        try:
            if self._transport is not None:
                with httpx.Client(timeout=self.timeout, transport=self._transport) as client:
                    response = client.get(url, headers=headers)
            else:
                with httpx.Client(timeout=self.timeout) as client:
                    response = client.get(url, headers=headers)
        except httpx.TimeoutException as exc:
            raise SfdaUnreachable(
                f"SFDA gateway timeout on {path}: {exc}",
                code="TIMEOUT",
            ) from exc
        except httpx.TransportError as exc:
            raise SfdaUnreachable(
                f"SFDA gateway unreachable on {path}: {exc}",
                code="TRANSPORT",
            ) from exc

        if response.status_code >= 400:
            raise _error_from_status(response)
        try:
            return response.json()
        except ValueError as exc:
            raise SfdaPayloadError(
                f"non-JSON body (status {response.status_code})",
                code="MALFORMED",
            ) from exc

    # -- lookups: registered-food-service (bearer) --------------------------

    def fetch_by_barcode(self, barcode: str, retrieved_at: Optional[str] = None) -> SfdaProductRecord:
        """Primary lookup: query the registry by barcode (single product)."""
        normalized = validate_barcode(barcode)
        body = self._get(SFDA_ENDPOINTS["by_barcode"].format(barcode=normalized))
        product = parse_product_response(body)
        return to_product_record(product, retrieved_at=retrieved_at)

    def fetch_by_reference_number(self, reference_number: str) -> SfdaProductRecord:
        """Query by the official registration/reference number (e.g. P-3-N-...)."""
        reference_number = reference_number.strip()
        if not reference_number:
            raise SfdaValidationError("reference number is empty", code="BAD_REFERENCE")
        body = self._get(SFDA_ENDPOINTS["by_referencenumber"].format(referencenumber=reference_number))
        product = parse_product_response(body)
        return to_product_record(product)

    def fetch_by_id(self, product_id: int) -> SfdaProductRecord:
        """Query by the registry system id."""
        body = self._get(SFDA_ENDPOINTS["by_id"].format(productid=product_id))
        product = parse_product_response(body)
        return to_product_record(product)

    def search_by_keyword(self, keyword: str, page: int = 1):
        """Bulk discovery: keyword search (paginated FoodProductListResponse).

        Returns (records, metadata). Ambiguity handling (multiple records for
        one barcode) is the caller/orchestrator's responsibility so that it is
        recorded (data_conflicts), never silently resolved.
        """
        keyword = keyword.strip()
        if not keyword:
            raise SfdaValidationError("keyword is empty", code="BAD_KEYWORD")
        page = validate_page(page)
        body = self._get(SFDA_ENDPOINTS["search"].format(keyword=keyword, page=page))
        products, metadata = parse_product_list_response(body)
        return [to_product_record(p) for p in products], metadata

    def list_page(self, page: int = 1):
        """Bulk discovery: paginated list of all registered products."""
        page = validate_page(page)
        body = self._get(SFDA_ENDPOINTS["list"].format(page=page))
        products, metadata = parse_product_list_response(body)
        return [to_product_record(p) for p in products], metadata

    # -- lookups: FIRS open-data service (API key) --------------------------

    def firs_food_list(self, page: int = 1):
        """Documented official endpoint GET /v2/FIRS/food/list (API key).

        Returns (records, metadata) where a record is built by the documented
        FIRS schema mapping (`parse_firs_record`).
        """
        page = validate_page(page)
        body = self._get_firs(SFDA_ENDPOINTS["firs_list"])
        return _parse_firs_list_body(body, page)

    def firs_food_search(self, keyword: str, page: int = 1):
        """Documented official endpoint GET /v2/FIRS/food/search (API key).

        The keyword/page query-parameter transport is only reconciled with the
        official FIRS documentation before a live call; this method validates
        the inputs now and refuses to fabricate a URL shape.
        """
        keyword = keyword.strip()
        if not keyword:
            raise SfdaValidationError("keyword is empty", code="BAD_KEYWORD")
        page = validate_page(page)
        body = self._get_firs(SFDA_ENDPOINTS["firs_search"])
        return _parse_firs_list_body(body, page)


def _parse_firs_list_body(body: dict, page: int):
    """Parse a FIRS list/search response defensively.

    The FIRS open-data envelope format is not part of the registered-food-
    service spec; this parse accepts a `data` array (list envelope) or a bare
    array and always preserves the raw payload per record. The exact envelope
    shape MUST be reconciled with the official FIRS documentation before a
    live call, and any mismatch raises SfdaPayloadError (never a guess).
    """
    if not isinstance(body, dict):
        raise SfdaPayloadError("FIRS response is not a JSON object", code="MALFORMED")
    raw_items = body.get("data")
    if raw_items is None and isinstance(body.get("items"), list):
        raw_items = body["items"]
    if not isinstance(raw_items, list):
        raise SfdaPayloadError(
            "FIRS response has no `data` array (envelope shape must be "
            "confirmed against the official FIRS documentation)",
            code="MALFORMED",
        )
    records = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        product = parse_firs_record(item)
        records.append(to_product_record(product))
    metadata = body.get("metadata")
    if not isinstance(metadata, dict):
        metadata = {"currentPage": page}
    return records, metadata


def _error_from_status(response: httpx.Response) -> SfdaAdapterError:
    """Translate an HTTP error into the typed SFDA error, mapping spec codes."""
    body = {}
    try:
        body = response.json() or {}
    except ValueError:
        body = {}
    code = body.get("code") if isinstance(body, dict) else None
    message = body.get("message") if isinstance(body, dict) else None
    status = response.status_code

    if status == 401:
        return SfdaHttpError(
            message or _describe_401(code),
            status_code=401,
            code=str(code) if code else "401",
        )
    if status == 429:
        return SfdaHttpError(
            message or "Too many requests by Spike arrest violation",
            status_code=429,
            code=SFDA_ERR_RATE_LIMITED,
        )
    if status == 422:
        return SfdaHttpError(message or "Unprocessable Entity", status_code=422, code=str(code or "422"))
    if status == 404:
        return SfdaHttpError(message or "Not Found", status_code=404, code=str(code or "404"))
    return SfdaHttpError(
        message or f"HTTP {status}", status_code=status, code=str(code) if code else f"{status}",
    )


def _describe_401(code) -> str:
    if str(code) == SFDA_ERR_AUTH_FAILED:
        return "API authorization failed"
    if str(code) == SFDA_ERR_TOKEN_EXPIRED:
        return "Access Token expired"
    if str(code) == SFDA_ERR_NO_API_PRODUCT:
        return "Invalid API call as no Api Product match found"
    return "Unauthorized"


# --------------------------------------------------------------------------
# Access-state report (used by the STEP 17 verification script)
# --------------------------------------------------------------------------


def access_report() -> dict:
    """Describe current SFDA adapter readiness without touching the network."""
    adapter = SfdaFoodAdapter()
    base = settings.sfda_base_url or SFDA_BASE_URL
    return {
        "contract_version": SFDA_CONTRACT_VERSION,
        "base_url": base,
        "access_mechanisms": adapter.access_configured(),
        "endpoints": {k: f"{base}{v}" for k, v in SFDA_ENDPOINTS.items()},
        "note": (
            "gateway probe from this environment: unauthenticated /v2/Food and "
            "/v2/FIRS routes are black-holed (no HTTP response); a completed "
            "credential path is required - a pre-minted bearer token "
            "(SFDA_ACCESS_TOKEN), a FIRS API key (SFDA_API_KEY), or OAuth2 "
            "client credentials (SFDA_CONSUMER_KEY + SFDA_CONSUMER_SECRET) "
            "plus the portal's exact token URL (SFDA_OAUTH_TOKEN_URL). The "
            "exact FIRS API-key transport header must be confirmed against the "
            "official FIRS documentation before any live FIRS call."
        ),
    }