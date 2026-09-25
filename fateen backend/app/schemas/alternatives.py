from pydantic import BaseModel, Field

from app.schemas.compatibility import ProductSummary


class AlternativeCandidate(BaseModel):
    product: ProductSummary
    reason: str


class AlternativesResponse(BaseModel):
    original_product: ProductSummary
    alternatives: list[AlternativeCandidate] = Field(default_factory=list)
    # Transparency fields so the client/UI can tell "we checked 12
    # candidates and none were confirmed safe" apart from "we found
    # nothing to check" -- both render as an empty list otherwise.
    candidates_considered: int
    candidates_confirmed_safe: int
