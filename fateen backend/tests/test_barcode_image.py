"""POST /api/v1/products/barcode-from-image: the web app's photo scan."""
import base64
import io

import pytest
from PIL import Image, ImageFilter

zxingcpp = pytest.importorskip("zxingcpp")

ENDPOINT = "/api/v1/products/barcode-from-image"


def _png(barcode: str, fmt, scale: int = 4) -> Image.Image:
    image = zxingcpp.create_barcode(barcode, fmt).to_image(scale=scale)
    return image if isinstance(image, Image.Image) else Image.fromarray(image)


def _b64(image: Image.Image, fmt: str = "PNG") -> str:
    buf = io.BytesIO()
    image.save(buf, fmt)
    return base64.b64encode(buf.getvalue()).decode()


def test_reads_a_product_barcode_from_a_phone_like_photo(authenticated_client):
    canvas = Image.new("L", (3000, 2200), 200)
    code = _png("6281007032261", zxingcpp.BarcodeFormat.EAN13).convert("L")
    canvas.paste(code.resize((code.width * 2, code.height * 2)), (900, 800))
    photo = canvas.rotate(12, fillcolor=180).filter(ImageFilter.GaussianBlur(1.5))
    response = authenticated_client.post(ENDPOINT, json={"image_base64": _b64(photo, "JPEG")})
    assert response.status_code == 200
    assert response.json() == {"barcode": "6281007032261"}


def test_a_qr_code_is_not_a_product_barcode(authenticated_client):
    qr = _png("https://example.com", zxingcpp.BarcodeFormat.QRCode, scale=6)
    response = authenticated_client.post(ENDPOINT, json={"image_base64": _b64(qr)})
    assert response.json() == {"barcode": None}


def test_not_an_image_is_400(authenticated_client):
    payload = base64.b64encode(b"definitely not a picture").decode()
    assert authenticated_client.post(ENDPOINT, json={"image_base64": payload}).status_code == 400


def test_requires_sign_in(client):
    assert client.post(ENDPOINT, json={"image_base64": "x" * 20}).status_code == 401


def test_served_by_the_public_gateway():
    from app.public_gateway import is_public
    assert is_public("POST", ENDPOINT)
    assert not is_public("GET", ENDPOINT)
