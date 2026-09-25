from app.repositories.product_repository import get_products_count


def get_database_summary() -> dict:
    return {
        "products": get_products_count(),
    }
