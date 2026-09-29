"""Read a product barcode from a photo.

The web app cannot decode a picked photo in the browser (mobile_scanner has
no image analysis on the web), so it sends the photo here. Only retail
product symbologies are read (EAN-13, EAN-8, UPC-A, UPC-E), and a value
must pass the GS1 check digit, so a QR code or a misread never reaches the
product lookup.
"""
import base64
import binascii
import io
from typing import Optional

from PIL import Image, ImageOps, UnidentifiedImageError

from app.core.gtin import has_valid_check_digit

MAX_SIDE = 2000  # larger photos are scaled down: faster, and just as readable


class InvalidImage(ValueError):
    pass


def _load(image_base64: str) -> Image.Image:
    data = image_base64.split(",", 1)[1] if image_base64.startswith("data:") else image_base64
    try:
        raw = base64.b64decode(data, validate=True)
        image = Image.open(io.BytesIO(raw))
        image = ImageOps.exif_transpose(image)  # phone photos are often stored rotated
        image.load()
    except (binascii.Error, ValueError, UnidentifiedImageError, OSError) as exc:
        raise InvalidImage("الملف ليس صورة صالحة") from exc
    image = image.convert("L")
    image.thumbnail((MAX_SIDE, MAX_SIDE))
    return image


def read_barcode(image_base64: str) -> Optional[str]:
    """The first valid retail barcode in the photo, or None."""
    import zxingcpp

    formats = (zxingcpp.BarcodeFormat.EAN13 | zxingcpp.BarcodeFormat.EAN8
               | zxingcpp.BarcodeFormat.UPCA | zxingcpp.BarcodeFormat.UPCE)
    image = _load(image_base64)
    for result in zxingcpp.read_barcodes(image, formats=formats):
        text = (result.text or "").strip()
        if has_valid_check_digit(text):
            return text
    return None
