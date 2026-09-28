"""Token verification must work on hosts without Google credentials.

Outside Google Cloud (e.g. Render) there are no Application Default
Credentials. Verifying a Firebase ID token only needs Google's public
signing keys, so with just FIREBASE_PROJECT_ID the check must reach the
token's claims instead of failing on a missing credential.
"""
import firebase_admin
import pytest

from app.core import auth


@pytest.fixture
def fresh_firebase_app(monkeypatch):
    monkeypatch.delenv("GOOGLE_APPLICATION_CREDENTIALS", raising=False)
    monkeypatch.setenv("FIREBASE_PROJECT_ID", "fateen-test-project")
    monkeypatch.setattr(auth, "_firebase_app", None)
    yield
    if auth._firebase_app is not None:
        firebase_admin.delete_app(auth._firebase_app)
    auth._firebase_app = None


def test_app_initialises_without_application_default_credentials(fresh_firebase_app):
    app = auth._get_firebase_app()
    assert app is not None
    assert app.project_id == "fateen-test-project"
    app.credential.get_credential()  # must not look for ADC


def test_invalid_token_rejected_on_its_claims(fresh_firebase_app, monkeypatch):
    from google.auth.exceptions import DefaultCredentialsError
    from firebase_admin import auth as firebase_auth

    reasons = []
    real_verify = firebase_auth.verify_id_token

    def spy(token, app=None, **kwargs):
        try:
            return real_verify(token, app=app, **kwargs)
        except Exception as exc:
            reasons.append(exc)
            raise

    monkeypatch.setattr(firebase_auth, "verify_id_token", spy)
    assert auth.verify_firebase_token("not-a-jwt") is None
    assert reasons and not isinstance(reasons[0], DefaultCredentialsError)
