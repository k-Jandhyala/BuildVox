# BuildVox

**BuildVox** is a construction jobsite communication application. It connects field workers, general contractors (GCs), trade managers, and administrators so teams can capture voice memos and text updates, turn them into structured action items, coordinate tasks across trades, and stay aligned on blockers, materials, and safety.

The primary client is a **Flutter** mobile/desktop app (`frontend/`). **Authentication and persistent data** use **Supabase** (PostgreSQL + Auth + Storage). **Firebase** is used for **Firebase Cloud Messaging (FCM)** push notifications and hosts **Cloud Functions** that perform AI extraction (Google Gemini), task workflows, and optional demo seeding.

---

## Table of contents

1. [What the product does](#what-the-product-does)
2. [High-level architecture](#high-level-architecture)
3. [Repository layout](#repository-layout)
4. [Tech stack](#tech-stack)
5. [Prerequisites](#prerequisites)
6. [Configuration and secrets](#configuration-and-secrets)
7. [Setup (step by step)](#setup-step-by-step)
8. [Running the app](#running-the-app)
9. [Firebase Cloud Functions](#firebase-cloud-functions)
10. [Database and Supabase migrations](#database-and-supabase-migrations)
11. [User roles and routing](#user-roles-and-routing)
12. [Frontend structure (overview)](#frontend-structure-overview)
13. [Demo data and offline behavior](#demo-data-and-offline-behavior)
14. [Additional documentation](#additional-documentation)
15. [Troubleshooting](#troubleshooting)

---

## What the product does

At a high level, BuildVox supports:

- **Sign-in** with email and password (Supabase Auth), with role-aware home screens.
- **Trade workers** (e.g. **Electrician**, **Plumber**): dedicated shells with **Home**, **Tasks**, **Update** (field notes with typed tags), **Warnings**, and **Profile**; quick actions for materials, blockers, site plan, etc.
- **General Contractor (GC)**: site-level overview, trades summary, **Updates** (same field-note flow with GC-oriented tags), **Warnings**, and profile.
- **Manager**: multi-jobsite **Dashboard**, **Updates**, **Jobsites**, **Approvals** (material requests / work orders), **Reports** placeholders, and profile.
- **Admin**: operational tools (e.g. seeding, summaries) depending on implementation.
- **Voice memo pipeline** (where enabled): record or upload audio, upload to storage, call Cloud Functions for **Gemini**-based extraction into structured items (blockers, materials, progress, etc.), with review and submission flows.
- **Text field notes / updates**: workers and GC can submit categorized text updates; items can be queued when offline and synced when connectivity returns.
- **Tasks**: assignments with status updates, detail screens, and navigation from home and task lists.
- **Push notifications**: FCM registration and background handler (Firebase initialized in the app for messaging).

The UI uses a consistent dark theme, role-colored accents, and shared components for navigation, modals, and field-note tagging.

---

## High-level architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter app (frontend/)                                         │
│  • go_router + Riverpod                                          │
│  • Supabase Flutter (auth session, DB access via app layer)      │
│  • HTTP → Firebase Cloud Functions (Bearer: Supabase JWT)        │
│  • Optional: Supabase Storage for uploads                         │
│  • Firebase Core: FCM only                                      │
└───────────────┬─────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│  Supabase                                                        │
│  • Auth (email/password)                                         │
│  • PostgreSQL + Row Level Security (see supabase/migrations)      │
│  • Storage buckets (e.g. voice memos, photos)                     │
└───────────────┬─────────────────────────────────────────────────┘
                │
                ▼
┌─────────────────────────────────────────────────────────────────┐
│  Firebase (project)                                              │
│  • Cloud Functions (Node/TypeScript) — HTTP endpoints             │
│  • Gemini (via @google/generative-ai) for audio/text extraction  │
│  • FCM for push (client uses firebase_messaging)                 │
│  • firebase.json also references Firestore/Storage emulators;    │
│    the live app data path is Supabase unless you customize it.   │
└─────────────────────────────────────────────────────────────────┘
```

**Important:** The checked-in `SETUP.md` describes a **Firebase-first** (Firestore) workflow in several places. The **current** `frontend/lib/main.dart` explicitly states that **Firebase is only used for FCM** and **auth + database are Supabase**. Use this README for the active stack; use `SETUP.md` as supplementary material for Firebase CLI, emulators, and Functions deployment patterns.

---

## Repository layout

| Path | Purpose |
|------|---------|
| **`frontend/`** | Flutter application (Dart 3.3+, all major platforms). |
| **`functions/`** | Firebase Cloud Functions (TypeScript): Gemini extraction, task APIs, seed endpoints, etc. |
| **`supabase/`** | SQL migrations and seed scripts for the Supabase database. |
| **`firebase.json`** | Firebase project config (Functions, optional Firestore/Storage rules, emulator ports). |
| **`dev-up.sh`** | Convenience script: starts Functions emulator + runs Flutter on Android with `dart-define` values. |
| **`SETUP.md`** | Extended setup notes (Firebase-centric sections + command reference). |

---

## Tech stack

| Layer | Technology |
|-------|------------|
| **Mobile / desktop UI** | Flutter (Material 3 styling in app theme) |
| **State management** | Riverpod (`flutter_riverpod`) |
| **Routing** | go_router |
| **Auth & database** | Supabase (`supabase_flutter`) |
| **Backend APIs** | Firebase Cloud Functions (HTTP), called with `Authorization: Bearer <Supabase access token>` |
| **AI** | Google Gemini (via Cloud Functions, `@google/generative-ai`) |
| **Push** | Firebase Cloud Messaging |
| **HTTP client** | `http` package for Functions |
| **Local persistence** | path_provider, JSON-backed queues where implemented (e.g. offline submissions) |

---

## Prerequisites

Install the following on your development machine:

1. **Flutter SDK** (SDK constraint: `>=3.3.0 <4.0.0` per `frontend/pubspec.yaml`). Run `flutter doctor` and resolve any reported issues.
2. **Dart** (bundled with Flutter).
3. **Node.js 18+** (for Cloud Functions; see `functions/package.json` `engines`).
4. **npm** (for Functions: `npm install`, `npm run build`).
5. **Firebase CLI** (`npm install -g firebase-tools`) if you deploy or emulate Functions.
6. A **Supabase project** (URL + anon key) with schema applied from `supabase/migrations/`.
7. A **Firebase project** (for FCM + hosting Functions) if you use cloud endpoints and push notifications.

**Platform toolchains** (install as needed):

- **Android**: Android Studio / SDK, emulator or USB device.
- **iOS** (optional): Xcode, CocoaPods.
- **Windows / Linux / macOS**: desktop support is present under `frontend/` platform folders.

---

## Configuration and secrets

### Supabase (Flutter)

The Flutter app reads Supabase settings from **compile-time** `String.fromEnvironment` / `bool.fromEnvironment` in `frontend/lib/services/supabase_service.dart` and related services:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

If you do not pass `--dart-define`, the code may fall back to **default values** embedded for development. For any shared or production build, **override** these with your own project’s URL and anon key. The anon key is still a **public** client key; true protection comes from **Supabase Row Level Security** and server-side policies.

Optional:

- `SUPABASE_STORAGE_BUCKET` (e.g. for voice memo storage paths — see `dev-up.sh` and storage usage in services).

### Firebase Cloud Functions (HTTP base URL)

`frontend/lib/services/functions_service.dart` uses:

| Define | Purpose |
|--------|---------|
| `FIREBASE_PROJECT_ID` | GCP/Firebase project ID used in function URLs. |
| `FIREBASE_FUNCTIONS_REGION` | Region (default `us-central1`). |
| `USE_FIREBASE_EMULATOR` | `true` to call `http://<host>:5001/...` emulators. |
| `FIREBASE_EMULATOR_HOST` | Host reachable from the app (Android emulator often uses `10.0.2.2` for the host machine). |

### Functions environment (backend)

In `functions/`, copy `.env.example` to `.env` (if present in your clone) and set variables such as:

- `GEMINI_API_KEY` — for real Gemini calls.
- `DEMO_MODE` — when `true`, some paths can return canned data without calling Gemini (useful for local testing; see `SETUP.md` and `functions/src/gemini.ts`).

For deployed Functions, configure secrets via Firebase (`firebase functions:config:set` or newer Secret Manager patterns) per your team’s practice.

### Firebase client (FCM only)

Firebase is initialized in `frontend/lib/main.dart` for messaging. You still need valid **`firebase_options.dart`** (typically generated with FlutterFire CLI) and platform-specific config (e.g. Android `google-services.json`) for a real FCM-enabled build.

---

## Setup (step by step)

### 1. Clone the repository

```bash
git clone <your-fork-or-origin-url> BuildVox
cd BuildVox
```

### 2. Supabase database

1. Create a project at [supabase.com](https://supabase.com).
2. Run SQL in order from `supabase/migrations/` (filenames are timestamp-prefixed).
3. Optionally run `supabase/seed_demo_data.sql` or use app/Functions seeding where applicable.
4. Confirm **Auth** providers (email/password) are enabled.
5. Review **RLS** policies in migrations so authenticated users can read/write according to your security model.

### 3. Flutter dependencies

```bash
cd frontend
flutter pub get
flutter analyze
```

### 4. Cloud Functions dependencies

```bash
cd functions
npm install
npm run build
```

Confirm `functions/lib/` is generated (TypeScript `npm run build`).

### 5. Firebase project (Functions + FCM)

1. Create or select a Firebase project.
2. `firebase login` and `firebase use <project-id>` at the repo root (see `.firebaserc`).
3. For Android FCM: register the app and add `google-services.json` under `frontend/android/app/` as required by your package name.
4. Generate `frontend/lib/firebase_options.dart` using FlutterFire if not present:

   ```bash
   cd frontend
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

### 6. Align package IDs and URLs

Ensure Android `applicationId`, iOS bundle ID, and Firebase/Supabase console settings match the values you use in builds.

---

## Running the app

### Basic: Flutter run

From `frontend/`:

```bash
flutter run
```

Pass Supabase (and optional Functions) defines as needed:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

For **local Functions emulator** (must be running separately):

```bash
flutter run \
  --dart-define=USE_FIREBASE_EMULATOR=true \
  --dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2 \
  --dart-define=FIREBASE_PROJECT_ID=your-firebase-project-id \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key
```

On a **physical device**, replace `10.0.2.2` with your computer’s LAN IP address.

### Convenience script: `dev-up.sh`

The repo includes `dev-up.sh`, which:

- Tries to start an Android emulator (configurable `AVD_NAME`, default `Pixel_7_Pro`).
- Starts **`firebase emulators:start --only functions`** in the background.
- Runs `flutter run` with a set of `--dart-define` flags (Supabase URL/key defaults, emulator flags, storage bucket).

Requirements: `bash`, `flutter`, `firebase`, `adb`, `curl` (as used in the script). On Windows, use Git Bash, WSL, or adapt the commands manually.

Environment overrides (examples):

```bash
export SUPABASE_URL="https://....supabase.co"
export SUPABASE_ANON_KEY="..."
./dev-up.sh
```

---

## Firebase Cloud Functions

HTTP functions are defined in `functions/src/index.ts` (built to `functions/lib/`). Exported endpoints include (names subject to evolution):

| Export | Typical purpose |
|--------|------------------|
| `submitVoiceMemo` | Submit a voice memo for processing. |
| `startVoiceMemoProcessing` | Start async processing pipeline. |
| `pollVoiceMemoProcessing` | Poll processing status/results. |
| `submitReviewedItems` | Submit user-reviewed extracted items. |
| `assignTask` | Assign tasks to workers. |
| `updateTaskStatus` | Update task status. |
| `generateDailyDigest` | Generate digest content. |
| `seedDemoDataFn` / `seedDemoDataHttp` | Demo data seeding (protect or remove in production). |

All app calls use **Supabase session JWT** in the `Authorization` header (`FunctionsService`).

Deploy example:

```bash
cd functions && npm run build && cd ..
firebase deploy --only functions
```

---

## Database and Supabase migrations

| File (examples) | Description |
|-------------------|-------------|
| `supabase/migrations/*_buildvox_app_schema.sql` | Core tables and policies. |
| `supabase/migrations/*_rls_allow_authenticated.sql` | RLS adjustments for authenticated roles. |
| `supabase/migrations/*_ai_review_requests.sql` | AI review request storage. |
| `supabase/seed_demo_data.sql` | Seed data for demos. |

Apply these in your Supabase SQL editor or via the Supabase CLI linked to your project.

---

## User roles and routing

Routing is implemented in `frontend/lib/router.dart` with **go_router** and a **Supabase session** gate:

- Not signed in → `/login`.
- Signed in on `/login` → redirected to the correct home by `homeRouteForUser()`.

**Roles** (`UserRole` in `user_model.dart`): `worker`, `gc`, `manager`, `admin`.

**Trade** (`TradeType`): e.g. `electrical`, `plumbing`, … — used to choose **Electrician** vs **Plumber** shells vs generic **Worker** home.

Approximate home destinations:

| Role / trade | Primary shell / route |
|--------------|------------------------|
| Worker + electrical | `ElectricianShellScreen` (`/electrician` hierarchy) |
| Worker + plumbing | `PlumberShellScreen` (`/plumber` hierarchy) |
| Worker (other trade) | `WorkerHome` (`/worker`) |
| GC | `GcHome` (`/gc`) |
| Manager | `ManagerHome` (`/manager`) |
| Admin | `AdminHome` (`/admin`) |

Nested routes exist for task detail, electrician/plumber task detail, AI review, etc. See `router.dart` for the full tree.

### Demo accounts (login screen)

The login UI includes quick-fill chips for common demo emails. Passwords are typically shared across demos (e.g. `BuildVox2024!` — confirm in `frontend/lib/screens/auth/login_screen.dart` and your seeded `app_users` data). Example emails:

- `electrician@demo.com` — Electrician worker  
- `plumber@demo.com` — Plumber worker  
- `gc@demo.com` — General contractor  
- `manager@demo.com` — Manager  
- `admin@demo.com` — Admin  

These only work if the same users exist in **Supabase Auth** and your **`app_users`** (or equivalent) tables with matching roles.

---

## Frontend structure (overview)

```
frontend/lib/
├── main.dart              # WidgetsFlutterBinding, Firebase init, Supabase init, FCM background handler
├── app.dart               # Material app + router
├── router.dart            # go_router, auth redirect
├── theme.dart             # BVColors, themeData
├── models/                # User, job site, extracted items, assignments, etc.
├── providers/             # Riverpod: auth, projects, electrician/GC/manager state, etc.
├── services/              # Supabase, database access, Functions HTTP, storage, notifications, offline queue
├── screens/
│   ├── auth/              # Login
│   ├── electrician/       # Shell, home, tasks, record/update, warnings, profile, task detail, AI review
│   ├── plumber/           # Parallel shell + screens for plumbing trade
│   ├── gc/                # GC home, task board, feeds, blockers, schedule, digest, …
│   ├── manager/           # Dashboard, jobsites, approvals, reports, profile
│   ├── admin/               # Admin tools
│   └── worker/              # Generic worker home, tasks, task detail, submit memo, field note config, chip row
├── widgets/               # Shared UI (account menu, modals, shimmer, etc.)
└── data/
    └── mock_data.dart     # Consolidated mock/demo data for previews (jobsites, tasks, warnings, etc.)
```

Key shared **Update / field note** UI:

- `screens/worker/trade_field_note_config.dart` — tag definitions per layout (electrician, plumber, GC, manager).
- `screens/worker/field_note_tag_chip_row.dart` — update-type chip row.
- `screens/electrician/electrician_record_screen.dart` — main field note / update screen used across roles (with different `TradeFieldNoteLayout` and `FieldNoteHost`).

---

## Demo data and offline behavior

- **`frontend/lib/data/mock_data.dart`** centralizes mock jobsites, tasks, warnings, field notes, approvals, and dashboard stats for UI previews and demos.
- **Offline queue**: queued submissions (e.g. when the device cannot reach Cloud Functions) may be stored locally and retried; see `offline_queue_service.dart` and `electrician_provider.dart` queue handling.

---

## Additional documentation

| Document | Contents |
|----------|----------|
| **`SETUP.md`** | Detailed Firebase/Gemini/emulator/seed workflows, limitations, and command reference. Some sections assume Firestore — cross-check with this README for the Supabase-first app behavior. |
| **`firebase.json`** | Emulator ports and which Firebase products are wired for CLI deploy/emulate. |
| **`supabase/migrations/*.sql`** | Authoritative schema documentation in SQL form. |

---

## Troubleshooting

| Issue | Suggestions |
|-------|-------------|
| **Supabase not configured** | Ensure `SUPABASE_URL` and `SUPABASE_ANON_KEY` are passed via `--dart-define` or that intentional defaults match your project. |
| **401 / 403 from Cloud Functions** | Confirm the user is signed in to Supabase and the `Authorization: Bearer` token is sent (`FunctionsService`). Check Functions CORS and deployed region. |
| **Functions emulator connection failed** | Firewall, wrong `FIREBASE_EMULATOR_HOST`, or emulator not listening on port `5001`. |
| **FCM not receiving pushes** | Requires real device + valid `google-services.json` / iOS equivalent; emulators often won’t deliver real pushes. |
| **Gradle / Android build errors** | Run `flutter doctor`; verify package name and `google-services.json` placement. |
| **RLS errors from Supabase** | Review policies in migrations; ensure `app_users` (or your profile table) rows exist for the auth user UUID. |

---

## License

No `LICENSE` file is present in this repository by default. Add one if you open-source or distribute the project.

---

*This README reflects the repository state at the time of writing. When in doubt, prefer `frontend/lib/main.dart`, `frontend/lib/services/`, and `functions/src/index.ts` as the source of truth for runtime behavior.*
