# Fateen team deployment

## Architecture prepared

- Firebase Hosting serves the Flutter Web build for `fateen-ap`.
- Hosting forwards `/api/**` to Cloud Run service `fateen-api` in `asia-northeast1`.
- The Cloud Run image starts the restricted `app.public_gateway` surface, which keeps ingestion, scan, company administration, vision, and docs private.
- Cloud Run verifies Firebase ID tokens through its attached service identity (`FIREBASE_PROJECT_ID=fateen-ap`). No service-account JSON is needed in production.
- The existing Supabase database remains the data store. Its runtime URL must be configured in Cloud Run Secret Manager as `DATABASE_URL`; do not copy it into source or image.

## Firebase project

The app moved to the Firebase project `fateen-ap` (owned by the team's
account) because the original `fateen-app` project was not reachable. Users
registered in `fateen-app` must register again. After cloning, regenerate
the app's Firebase files for `fateen-ap` once:

```bash
dart pub global activate flutterfire_cli
cd fateen1
flutterfire configure --project=fateen-ap
```

In the Firebase console of `fateen-ap`: enable Authentication with
Email/Password, create Firestore in production mode, and upgrade to Blaze.
`firebase deploy --only firestore:rules` publishes `firestore.rules` (each
user may read and write only `users/{their uid}`).

## Required Google Cloud setup before deployment

1. Enable Firebase Hosting and billing on project `fateen-ap`.
2. Create a Cloud Run service identity and grant it Secret Manager access to the runtime DB URL secret. Firebase Admin verifies tokens using Application Default Credentials and the configured project ID.
3. Create secrets for `DATABASE_URL` (existing least-privilege runtime role) and `AGENT_INGEST_API_KEY` (random, even though the public gateway blocks ingestion). Configure Cloud Run with `APP_ENV=production`, `FIREBASE_PROJECT_ID=fateen-ap`, `CORS_ALLOWED_ORIGINS=https://fateen-ap.web.app,https://fateen-ap.firebaseapp.com`, `DB_POOL_MIN_SIZE=1`, and `DB_POOL_MAX_SIZE=5`.
4. Build the Flutter app with `flutter build web --release --dart-define=FATEEN_API_SAME_ORIGIN=true`; deploy the backend image to Cloud Run as `fateen-api`, then deploy `build/web` with Firebase Hosting.
5. Verify team sign-in, search, barcode details, compatibility, and alternatives from a second device. Confirm unauthenticated compatibility and alternatives return 401.

## Without Google Cloud billing (Spark plan)

Cloud Run, Cloud Build and Secret Manager need a billing account; in Saudi
Arabia Google Cloud billing is handled by a local reseller and may not be
available to a personal account. Until it is, run the API on Render and keep
Firebase (Auth, Firestore, Hosting) on the free Spark plan:

1. On render.com create a **Web Service** from this GitHub repository, root
   directory `fateen backend`, runtime Docker, instance type Free.
2. Environment variables: `APP_ENV=production`, `FIREBASE_PROJECT_ID=fateen-ap`,
   `CORS_ALLOWED_ORIGINS=https://fateen-ap.web.app,https://fateen-ap.firebaseapp.com`,
   `DB_POOL_MIN_SIZE=1`, `DB_POOL_MAX_SIZE=5`, `DATABASE_URL` (the
   `fateen_app` runtime role) and `AGENT_INGEST_API_KEY` (random).
3. Build the web app against it and deploy Hosting without the Cloud Run rewrite:

   ```
   flutter build web --release --dart-define=FATEEN_API_BASE_URL=https://<service>.onrender.com
   firebase deploy --only hosting --project fateen-ap --config firebase.spark.json
   ```

A free Render service sleeps after 15 idle minutes; the first request after
that takes up to a minute, which the app's 75-second timeout allows.

## Deployment gates

This workspace has no Git remote, and Firebase CLI, Google Cloud CLI, and Docker daemon are unavailable here. A signed-in Google Cloud/Firebase deployment session is needed to create services and publish a stable team URL. Before deploying, confirm that allergy and disease profile values sent by compatibility/alternatives may be processed by the Fateen backend on Google Cloud Run in project `fateen-ap`; current calls send this health context along with the Firebase ID token. Hosting/API usage may incur Google Cloud charges.
