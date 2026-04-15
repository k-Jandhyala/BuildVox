# BuildVox — Complete Setup Guide

---

## 1. Architecture Summary

```
Android App (Flutter)
  └── Firebase Auth         — Email/password sign-in
  └── Cloud Firestore       — All data storage (real-time streams)
  └── Firebase Storage      — Audio file uploads
  └── Firebase Messaging    — Push notifications
  └── Cloud Functions       — Backend (callable functions)
        └── Gemini 1.5 Pro  — Audio transcription + extraction
        └── Routing logic   — Determines notification recipients
        └── FCM dispatch    — Sends push notifications
        └── Seed function   — Creates demo data
```

**Two audio processing modes:**
- **REAL MODE** (`DEMO_MODE=false`): uploads audio → Cloud Function downloads it → sends to Gemini 1.5 Pro → returns structured JSON
- **DEMO MODE** (`DEMO_MODE=true`): Cloud Function returns canned realistic extraction; no Gemini API key needed for local testing

---

## 2. Project Folder Structure

```
BuildVox/
├── frontend/                     Flutter app
│   ├── pubspec.yaml
│   ├── assets/
│   ├── android/
│   │   └── app/
│   │       ├── build.gradle      ← minSdk 21, google-services
│   │       └── src/main/
│   │           ├── AndroidManifest.xml
│   │           └── kotlin/com/buildvox/app/MainActivity.kt
│   └── lib/
│       ├── main.dart
│       ├── app.dart
│       ├── router.dart
│       ├── theme.dart
│       ├── firebase_options.dart  ← YOU MUST GENERATE THIS
│       ├── models/
│       ├── services/
│       ├── providers/
│       ├── screens/
│       │   ├── auth/login_screen.dart
│       │   ├── worker/
│       │   ├── gc/
│       │   ├── manager/
│       │   └── admin/
│       └── widgets/
├── functions/                    Cloud Functions backend
│   ├── package.json
│   ├── tsconfig.json
│   ├── .env.example              ← copy to .env and add your keys
│   └── src/
│       ├── index.ts              ← all exported functions
│       ├── gemini.ts             ← Gemini integration + demo fallback
│       ├── routing.ts            ← notification routing logic
│       ├── validators.ts         ← request + response validation
│       ├── seed.ts               ← demo data seeder
│       ├── types.ts              ← all TypeScript types
│       └── config.ts             ← env var helpers
├── firebase.json
├── firestore.rules
├── firestore.indexes.json
├── storage.rules
└── .firebaserc                   ← insert your project ID here
```

---

## 3. Prerequisites

Install these before starting:

```bash
# 1. Flutter SDK (3.19+)
#    https://docs.flutter.dev/get-started/install/windows

# 2. Android Studio (with Android SDK)
#    https://developer.android.com/studio

# 3. Node.js 18+
#    https://nodejs.org/

# 4. Firebase CLI
npm install -g firebase-tools

# 5. FlutterFire CLI
dart pub global activate flutterfire_cli

# 6. Verify Flutter is installed
flutter doctor
```

---

## 4. Firebase Project Setup

### 4a. Create a Firebase project

1. Go to https://console.firebase.google.com/
2. Click **Add Project** → name it `buildvox-demo` (or anything)
3. Disable Google Analytics if you want simpler setup
4. Click **Create project**

### 4b. Enable Authentication

1. Firebase Console → **Authentication** → **Get started**
2. **Sign-in method** → **Email/Password** → Enable → Save

### 4c. Enable Firestore

1. Firebase Console → **Firestore Database** → **Create database**
2. Choose **Start in production mode** (rules are in `firestore.rules`)
3. Select a region (e.g. `us-central1`)

### 4d. Enable Firebase Storage

1. Firebase Console → **Storage** → **Get started**
2. Choose **Start in production mode**
3. Select the same region as Firestore

### 4e. Enable Cloud Messaging

1. Firebase Console → **Project settings** → **Cloud Messaging**
2. FCM is enabled by default for Android apps

### 4f. Add Android App

1. Firebase Console → **Project settings** → click the Android icon
2. **Android package name**: `com.buildvox.app`
3. **App nickname**: BuildVox Android
4. Click **Register app**
5. **Download `google-services.json`** and place it at:
   ```
   frontend/android/app/google-services.json
   ```
   ⚠️ This file is required. The app will NOT build without it.

---

## 5. Firebase CLI Setup

```bash
# Login
firebase login

# In the repo root, set your project
firebase use YOUR_FIREBASE_PROJECT_ID

# Or edit .firebaserc:
# Replace "YOUR_FIREBASE_PROJECT_ID" with your real project ID
```

---

## 6. Flutter Firebase Options

From the `frontend/` directory:

```bash
cd frontend
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```

This generates `frontend/lib/firebase_options.dart` with your real keys,
overwriting the template file. **Run this command — do not manually fill in the template.**

---

## 7. Gemini API Key Setup

1. Go to https://aistudio.google.com/app/apikey
2. Click **Create API Key**
3. Copy the key

### For local emulator testing:

```bash
cd functions
cp .env.example .env
# Edit .env:
GEMINI_API_KEY=your_actual_key_here
DEMO_MODE=false
```

### For demo mode (no Gemini key needed):

```bash
# In functions/.env:
DEMO_MODE=true
```
This returns canned extraction results without calling Gemini.

### For production deployment:

```bash
firebase functions:config:set gemini.key="your_actual_key_here"
```

---

## 8. Backend Setup

```bash
# From the repo root:
cd functions

# Install dependencies
npm install

# Build TypeScript
npm run build

# Verify build succeeded — you should see lib/index.js
ls lib/
```

---

## 9. Flutter Setup

```bash
cd frontend

# Get packages
flutter pub get

# Verify there are no errors
flutter analyze
```

---

## 10. Running Locally with Firebase Emulator

The emulator lets you run the full stack locally without deploying.

### Start emulators:

```bash
# From repo root
firebase emulators:start
```

This starts:
- Auth emulator on port 9099
- Functions emulator on port 5001
- Firestore emulator on port 8080
- Storage emulator on port 9199
- Emulator UI on port 4000 → http://localhost:4000

### Connect the Flutter app to emulators:

In `frontend/lib/main.dart`, uncomment the emulator lines:

```dart
// Uncomment for emulator testing:
// FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
// FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
// FirebaseStorage.instance.useStorageEmulator('10.0.2.2', 9199);
// FunctionsService.useEmulator('10.0.2.2', 5001);
```

Note: `10.0.2.2` is the Android emulator's loopback to your host machine.
If testing on a **physical device** on the same WiFi, use your machine's LAN IP instead.

---

## 11. Android Studio Run Instructions

1. Open Android Studio
2. **File → Open** → select the `frontend/` folder
3. Wait for Gradle sync to complete (first time takes 2–5 minutes)
4. In the toolbar, select an Android Virtual Device or connect a physical device
5. Click the green **Run** button (or press Shift+F10)

**Minimum Android version:** API 21 (Android 5.0 Lollipop)

**If Gradle sync fails:**
- Ensure `google-services.json` is in `frontend/android/app/`
- Check that `firebase_options.dart` has been generated (not the template)
- Run `flutter doctor` and fix any issues

---

## 12. Seeding Demo Data

Demo data creates 5 users, 2 companies, 1 project, and 2 job sites.

### Option A: Via the app (after first deploying functions)

1. Sign in as `admin@demo.com` / `BuildVox2024!`
   - ⚠️ You need to create this auth account first via the HTTP endpoint below
2. Go to the Admin screen → Setup tab → **Run Seed**

### Option B: HTTP endpoint (first-time, before any users exist)

This endpoint bypasses auth and is intended for the very first seed only.
**Disable or delete `seedDemoDataHttp` from `index.ts` after first seed in production.**

```bash
# After deploying functions:
curl -X POST \
  https://us-central1-YOUR_PROJECT_ID.cloudfunctions.net/seedDemoDataHttp \
  -H "Content-Type: application/json" \
  -d '{"secret":"BuildVoxSeed2024"}'
```

### Option C: Emulator

```bash
# With emulators running:
curl -X POST \
  http://127.0.0.1:5001/YOUR_PROJECT_ID/us-central1/seedDemoDataHttp \
  -H "Content-Type: application/json" \
  -d '{"secret":"BuildVoxSeed2024"}'
```

### Demo accounts (after seeding):

| Email | Password | Role |
|-------|----------|------|
| gc@demo.com | BuildVox2024! | General Contractor |
| electrician@demo.com | BuildVox2024! | Worker (Electrical) |
| plumber@demo.com | BuildVox2024! | Worker (Plumbing) |
| manager@demo.com | BuildVox2024! | Trade Manager |
| admin@demo.com | BuildVox2024! | Admin |

---

## 13. Deploying to Firebase

```bash
# Deploy everything
firebase deploy

# Deploy only functions
firebase deploy --only functions

# Deploy only Firestore rules + indexes
firebase deploy --only firestore

# Deploy only Storage rules
firebase deploy --only storage
```

---

## 14. Testing the Full Flow

1. Sign in as `electrician@demo.com`
2. Go to **Voice Memo** tab
3. Select project: "Downtown Mixed-Use Tower", site: "Floors 1–5"
4. Tap **Record**, speak for a few seconds, tap **Stop Recording**
   - Or tap **Upload** to pick a pre-recorded audio file
5. Tap **Submit Memo**
   - In DEMO_MODE: instant canned extraction
   - In REAL mode: ~15–30 seconds for Gemini processing
6. Check the **GC** screen (sign in as `gc@demo.com`) → Blockers and Schedule Changes should show items
7. Check the **Manager** screen (sign in as `manager@demo.com`) → Incoming Requests should show items
8. Manager assigns a task to the electrician
9. Worker (electrician) sees the task in **My Tasks**
10. Worker taps task → marks as **Done**

---

## 15. Known Limitations

1. **Audio file size**: Gemini inline processing is capped at 20 MB. Long recordings (>10 min at 128kbps) may fail. For production, implement the Gemini Files API.

2. **FCM local testing**: FCM push notifications require a real Firebase project and a real device with Google Play Services. They won't work in the local emulator; use Firestore notification docs as the fallback.

3. **whereIn limit**: Firestore `whereIn` queries are limited to 10 items. If a user is assigned to >10 projects, only the first 10 are queried. For production, use subcollections or Firestore `in` chunks.

4. **No offline support**: Standard Firestore caching is active, but there's no explicit offline-first architecture. Works fine on good connectivity.

5. **First seed only**: The `seedDemoDataHttp` endpoint is protected only by a shared secret. Delete it from `index.ts` after initial seeding in any non-demo environment.

6. **record package on emulator**: Some Android emulators don't have a working microphone. Use a physical device or the **Upload** button with a pre-recorded `.m4a`/`.mp3` file.

7. **`google-services.json` not included**: This file is per-project and cannot be committed here. Every developer on the team must generate it from Firebase Console.

---

## 16. Next-Step Enhancements

- [ ] Gemini Files API for audio > 20MB
- [ ] Offline-first with Hive or Isar
- [ ] Real-time comment threads on extracted items
- [ ] Photo attachments on memos
- [ ] Inspector role with punch-list workflow
- [ ] PDF daily digest export
- [ ] Multi-project GC dashboard with cross-project analytics
- [ ] Webhook integration to Procore / Buildertrend
- [ ] Spanish / multilingual UI (Gemini already detects language)
- [ ] iOS support (no code changes needed, just add iOS Firebase config)
- [ ] Firebase App Check (anti-abuse)
- [ ] Pagination for large feeds
- [ ] Push notification deep links (tap notification → open specific item)

---

## Quick Command Reference

```bash
# Install backend deps + build
cd functions && npm install && npm run build && cd ..

# Install frontend deps
cd frontend && flutter pub get && cd ..

# Start all emulators
firebase emulators:start

# Seed demo data (emulator)
curl -X POST http://127.0.0.1:5001/YOUR_PROJECT_ID/us-central1/seedDemoDataHttp \
  -H "Content-Type: application/json" -d '{"secret":"BuildVoxSeed2024"}'

# Run Flutter app
cd frontend && flutter run

# Deploy everything to Firebase
firebase deploy

# View function logs
firebase functions:log
```
