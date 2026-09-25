"""Server-side Gemini vision call for dish-photo ingredient ESTIMATION.

This relocates the Gemini API call that used to run directly from Flutter
(lib/services/ai_vision_service.dart, with the key embedded in
lib/config/api_keys.dart). The key now lives only in this backend's
environment (GEMINI_API_KEY) and never reaches the client.

IMPORTANT -- scope boundary: this module is an extraction/estimation step
only. It returns an estimated dish name and ingredient list; it does NOT
decide, and must never be wired to decide, product SAFE/WARNING/DANGER
compatibility. That decision belongs solely to
app.services.compatibility_service, which does not import or depend on
this module in any way.

STATUS: IMPLEMENTED -- NOT RUN. This sandbox has no network access to
reach the real Gemini API. The request/response shape and error handling
have been verified against a mocked HTTP response (see the offline
verification harness used during this hardening pass), but this has never
been exercised against the real Gemini endpoint. Test manually against a
real GEMINI_API_KEY before relying on it in production.
"""
import base64
import binascii
import json
import logging
import os
from typing import Optional

import httpx

from app.schemas.vision import DishEstimationResponse

logger = logging.getLogger("fateen.services.vision")

_GEMINI_MODEL = "gemini-1.5-flash"
_GEMINI_ENDPOINT = (
    f"https://generativelanguage.googleapis.com/v1beta/models/"
    f"{_GEMINI_MODEL}:generateContent"
)

# Unchanged from the original Flutter-side prompt in ai_vision_service.dart
# -- relocated, not rewritten.
_PROMPT = (
    "حلل الصورة المرفقة لطبق طعام، وحدد اسم الطبق ومكوناته المحتملة.\n"
    "أرجع لي الرد بصيغة JSON فقط، بدون أي نص أو شرح إضافي، بهذا الشكل بالضبط:\n"
    '{"name": "اسم الطبق", "estimatedIngredients": ["مكون1", "مكون2", "مكون3"]}'
)

MAX_IMAGE_BYTES = 10 * 1024 * 1024  # 10MB decoded


class VisionServiceUnavailable(Exception):
    """Raised for any failure -- missing config, invalid image, upstream
    error, unparseable response. The API layer maps this to a clean 503.
    The message here is safe to show to a client (never includes the API
    key, raw upstream errors, or a traceback).
    """


def _get_api_key() -> Optional[str]:
    return os.environ.get("GEMINI_API_KEY")


async def estimate_dish_from_image(image_base64: str) -> DishEstimationResponse:
    api_key = _get_api_key()
    if not api_key:
        logger.error(
            "GEMINI_API_KEY is not configured -- dish estimation unavailable"
        )
        raise VisionServiceUnavailable("Dish photo estimation is not configured")

    try:
        image_bytes = base64.b64decode(image_base64, validate=True)
    except (binascii.Error, ValueError):
        raise VisionServiceUnavailable("Invalid image data")

    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise VisionServiceUnavailable("Image too large")

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": _PROMPT},
                    {
                        "inline_data": {
                            "mime_type": "image/jpeg",
                            "data": image_base64,
                        }
                    },
                ]
            }
        ]
    }

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(
                _GEMINI_ENDPOINT, params={"key": api_key}, json=payload
            )
        response.raise_for_status()
        data = response.json()
        raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
    except Exception:
        # Deliberately generic: never leak the upstream response body (it
        # could echo the request) or any part of api_key back to a client.
        logger.exception("Gemini dish estimation call failed")
        raise VisionServiceUnavailable("Dish photo estimation failed")

    cleaned_text = raw_text.replace("```json", "").replace("```", "").strip()
    try:
        parsed = json.loads(cleaned_text)
    except (json.JSONDecodeError, TypeError):
        logger.warning("Gemini returned non-JSON dish estimation output")
        raise VisionServiceUnavailable("Could not parse dish estimation")

    return DishEstimationResponse(
        name=parsed.get("name") or "غير معروف",
        estimated_ingredients=list(parsed.get("estimatedIngredients") or []),
    )
