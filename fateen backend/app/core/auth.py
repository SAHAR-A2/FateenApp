"""Firebase ID token verification for the FATEEN backend.

STATUS: WIRED IN. Uses a service-account file locally or Cloud Run ADC.
`Depends(require_authenticated_user)` IS attached to
POST /api/v1/products/barcode/{barcode}/compatibility and
POST /api/v1/products/barcode/{barcode}/alternatives in
app/api/products.py, and `firebase-admin` IS in requirements.txt/installed.
So the *code path* is live. What is still missing is deployment
configuration:

  - `_get_firebase_app()` reads `GOOGLE_APPLICATION_CREDENTIALS` when a
    key file is explicitly configured; otherwise `FIREBASE_PROJECT_ID`
    enables Application Default Credentials (the recommended Cloud Run
    service identity flow).
  - If neither is configured, `_get_firebase_app()` returns None,
    `verify_firebase_token()` then always returns None, and
    `require_authenticated_user` raises 401 for every request, including
    ones with a perfectly valid Firebase ID token. In that state the two
    routes above are effectively unusable, not "open" -- fail-closed, not
    fail-open -- but still broken from the Flutter app's point of view.

Required step to make compatibility/alternatives actually work end to end:
  1. On Cloud Run, attach a service identity with Firebase token verification
     permissions and set `FIREBASE_PROJECT_ID`; locally, use
     `GOOGLE_APPLICATION_CREDENTIALS` with a service-account file. Never
     commit a key or put it in Flutter.
  2. Test against the Firebase project (valid token accepted,
     missing/expired/invalid token rejected with 401) before relying on
     it in production.

Until auth is configured, POST .../compatibility and POST .../alternatives
will reject every request with 401 regardless of the token sent, as
documented in the FATEEN Architecture Audit report and in
lib/services/api_client.dart's class-level security note.
"""
import logging
import os
from typing import Optional

from fastapi import Header, HTTPException

logger = logging.getLogger("fateen.core.auth")

_firebase_app = None


def _get_firebase_app():
    """Lazily initializes the firebase_admin app. Returns None (never
    raises) if firebase_admin isn't installed or no credential is
    configured, so importing this module never breaks the app in an
    environment where auth enforcement hasn't been turned on yet.
    """
    global _firebase_app
    if _firebase_app is not None:
        return _firebase_app

    credential_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    project_id = os.environ.get("FIREBASE_PROJECT_ID")
    if not credential_path and not project_id:
        logger.warning(
            "Firebase auth not configured (set FIREBASE_PROJECT_ID for "
            "Application Default Credentials, or GOOGLE_APPLICATION_CREDENTIALS "
            "for an explicit service-account key). Requests fail closed."
        )
        return None

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = (
            credentials.Certificate(credential_path)
            if credential_path
            else credentials.ApplicationDefault()
        )
        options = {"projectId": project_id} if project_id else None
        _firebase_app = firebase_admin.initialize_app(cred, options=options)
        return _firebase_app
    except ImportError:
        logger.error(
            "firebase_admin is not installed (pip install firebase-admin) "
            "-- cannot verify Firebase ID tokens."
        )
        return None
    except Exception:
        logger.exception("Failed to initialize firebase_admin app")
        return None


def verify_firebase_token(token: str) -> Optional[str]:
    """Verifies a Firebase ID token and returns the Firebase UID, or None
    if verification is not configured/available or the token is invalid.
    Never raises -- callers decide what "no verified identity" means for
    their route.
    """
    app = _get_firebase_app()
    if app is None:
        return None

    try:
        from firebase_admin import auth as firebase_auth

        decoded = firebase_auth.verify_id_token(token, app=app)
        return decoded.get("uid")
    except Exception:
        logger.warning("Firebase ID token verification failed", exc_info=True)
        return None


async def require_authenticated_user(
    authorization: Optional[str] = Header(default=None),
) -> str:
    """FastAPI dependency: NOT CURRENTLY ATTACHED TO ANY ROUTE (see module
    docstring). When wired in, raises 401 for a missing/invalid token and
    otherwise returns the verified Firebase UID.
    """
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing bearer token")

    token = authorization.removeprefix("Bearer ").strip()
    uid = verify_firebase_token(token)
    if uid is None:
        raise HTTPException(status_code=401, detail="Invalid or unverifiable token")

    return uid
