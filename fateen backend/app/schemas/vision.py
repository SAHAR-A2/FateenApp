from pydantic import BaseModel, Field


class DishEstimationRequest(BaseModel):
    # Base64-encoded JPEG/PNG bytes. ~15MB cap on the encoded string is a
    # generous bound for a phone photo (base64 adds ~33% overhead over the
    # 10MB decoded-image cap enforced in vision_service.py) -- prevents an
    # oversized request from being accepted at all before it's even
    # decoded.
    image_base64: str = Field(..., min_length=1, max_length=15_000_000)


class DishEstimationResponse(BaseModel):
    name: str
    estimated_ingredients: list[str] = Field(default_factory=list)
