from unittest.mock import MagicMock
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db.connection import get_connection
from app.core.auth import require_authenticated_user


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def authenticated_client():
    """A client for routes protected by require_authenticated_user, using
    FastAPI's standard dependency_overrides mechanism to stand in for a
    verified Firebase identity. This does NOT disable auth in production --
    app.main:app itself is unmodified; only this test's local `app`
    reference gets the override, and it is removed after the test.
    """
    app.dependency_overrides[require_authenticated_user] = lambda: "test-uid"
    yield TestClient(app)
    app.dependency_overrides.pop(require_authenticated_user, None)


@pytest.fixture
def mock_db_connection():
    mock_conn = MagicMock()
    mock_conn.__enter__ = MagicMock(return_value=mock_conn)
    mock_conn.__exit__ = MagicMock(return_value=False)
    return mock_conn


@pytest.fixture
def db_conn():
    with get_connection() as conn:
        yield conn


@pytest.fixture(autouse=True)
def _fresh_health_rule_cache():
    """Health conditions and thresholds are cached per process; a test that
    changes them must not see another test's copy."""
    from app.collector import health_conditions
    health_conditions.clear_cache()
    yield
    health_conditions.clear_cache()


@pytest.fixture(autouse=True)
def _fresh_rate_limit():
    """The per-IP rate limiter counts every test client request; start each
    test with an empty window so a test's outcome never depends on how many
    requests earlier tests made."""
    from app.main import _rate_limit_store
    _rate_limit_store.clear()
    yield
