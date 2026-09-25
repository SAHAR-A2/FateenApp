from app.db.connection import get_connection


def check_database() -> dict:
    with get_connection() as conn:
        row = conn.execute(
            "SELECT current_database() AS database, version() AS version"
        ).fetchone()

    return row
