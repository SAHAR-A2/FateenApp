from app.repositories.product_repository import search_products
from app.schemas.search import ProductSearchResult, ProductSearchResponse

MIN_QUERY_LENGTH = 2
MAX_RESULTS = 25


def search_products_by_name(query: str, language: str = "ar") -> ProductSearchResponse:
    """FateenDB-backed product search. Returns an empty result set (not an
    error) for queries shorter than MIN_QUERY_LENGTH, to avoid overly broad
    scans triggered by single-character input.
    """
    cleaned = (query or "").strip()

    if len(cleaned) < MIN_QUERY_LENGTH:
        return ProductSearchResponse(query=cleaned, count=0, results=[])

    rows = search_products(cleaned, limit=MAX_RESULTS, language=language)
    results = [ProductSearchResult(**row) for row in rows]

    return ProductSearchResponse(query=cleaned, count=len(results), results=results)
