# Fateen team deployment

## Architecture prepared

- Firebase Hosting serves the Flutter Web build for `fateen-app`.
- Hosting forwards `/api/**` to Cloud Run service `fateen-api` in `asia-northeast1`.
- The Cloud Run image starts the restricted `app.public_gateway` surface, which keeps ingestion, scan, company administration, vision, and docs private.
- Cloud Run verifies Firebase ID tokens through its attached service identity (`FIREBASE_PROJECT_ID=fateen-app`). No service-account JSON is needed in production.
- The existing Supabase database remains the data store. Its runtime URL must be configured in Cloud Run Secret Manager as `DATABASE_URL`; do not copy it into source or image.

## Required Google Cloud setup before deployment

1. Enable Firebase Hosting and billing on project `fateen-app`.
2. Create a Cloud Run service identity and grant it Secret Manager access to the runtime DB URL secret. Firebase Admin verifies tokens using Application Default Credentials and the configured project ID.
3. Create secrets for `DATABASE_URL` (existing least-privilege runtime role) and `AGENT_INGEST_API_KEY` (random, even though the public gateway blocks ingestion). Configure Cloud Run with `APP_ENV=production`, `FIREBASE_PROJECT_ID=fateen-app`, `CORS_ALLOWED_ORIGINS=https://fateen-app.web.app,https://fateen-app.firebaseapp.com`, `DB_POOL_MIN_SIZE=1`, and `DB_POOL_MAX_SIZE=5`.
4. Build the Flutter app with `flutter build web --release --dart-define=FATEEN_API_SAME_ORIGIN=true`; deploy the backend image to Cloud Run as `fateen-api`, then deploy `build/web` with Firebase Hosting.
5. Verify team sign-in, search, barcode details, compatibility, and alternatives from a second device. Confirm unauthenticated compatibility and alternatives return 401.

## Deployment gates

This workspace has no Git remote, and Firebase CLI, Google Cloud CLI, and Docker daemon are unavailable here. A signed-in Google Cloud/Firebase deployment session is needed to create services and publish a stable team URL. Before deploying, confirm that allergy and disease profile values sent by compatibility/alternatives may be processed by the Fateen backend on Google Cloud Run in project `fateen-app`; current calls send this health context along with the Firebase ID token. Hosting/API usage may incur Google Cloud charges.
