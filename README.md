# CozyTalk

Anonymous 1-on-1 stranger chat — Flutter (Android + Web) + Firebase.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter SDK | 3.41+ | [flutter.dev](https://docs.flutter.dev/get-started/install) |
| Node.js | 24+ | [nodejs.org](https://nodejs.org) |
| Java 21 | 21+ | Required by the Firebase emulators and Android builds |
| firebase-tools | latest | `npm i -g firebase-tools` |
| gcloud CLI | any | [cloud.google.com/sdk](https://cloud.google.com/sdk/docs/install) — optional; needed for interest matching locally |

You also need to be invited to the `cozytalk-5d984` Firebase project before running against production.

---

## Quick start

**1. Install everything**

Linux / macOS:
```bash
./setup.sh
```

Windows (PowerShell):
```powershell
.\setup.ps1
```

Installs Flutter packages, runs code generation (Freezed + Riverpod), and installs Cloud Functions dependencies.

**2. Log into Firebase** *(first time only)*

```bash
firebase login
```

**2b. Enable local interest matching** *(optional, one time)*

```bash
gcloud auth application-default login
```

Without this, interest matching degrades gracefully to random matching — all other features work normally. `dev.sh` / `dev.ps1` will show a warning if this step is skipped.

**2c. Register your Android debug SHA-1 for Google Sign-In** *(one time per dev machine)*

Google Sign-In on Android requires your debug keystore's SHA-1 fingerprint to be registered in Firebase. Without it, the sign-in flow closes immediately with an auth error.

```bash
# Find your debug keystore (Linux/macOS — may be at either path)
keytool -list -v \
  -keystore ~/.config/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep "SHA1:"

# If the above is empty, try:
keytool -list -v \
  -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android 2>/dev/null | grep "SHA1:"
```

Copy the `SHA1:` value, then:

1. [Firebase Console](https://console.firebase.google.com) → **cozytalk-5d984** → Project Settings → Your apps → Android (`com.example.mobile`) → **Add fingerprint** → paste SHA-1 → Save
2. On the same page, click **Download google-services.json** and replace `apps/mobile/android/app/google-services.json`

This is per-machine — every developer must do it once. CI uses the release keystore SHA-1 which is already registered.

**3. Start developing**

```bash
./dev.sh                 # emulators + Flutter on Android
./dev.sh --web           # emulators + Flutter on Chrome
./dev.sh --prod          # Flutter → live Firebase (Android)
./dev.sh --prod --web    # Flutter → live Firebase (Chrome)
./dev.sh --emulator-only # emulators only, no Flutter (for running tests)
```

Windows: replace `./dev.sh` with `.\dev.ps1`.

The script starts all four Firebase emulators in the background, waits until every port is ready, then launches Flutter. `Ctrl+C` shuts everything down cleanly. A second terminal that detects the emulators are already running attaches without restarting them.

---

## Scripts reference

### `./dev.sh` — local development runner

| Flag | What it does |
|---|---|
| *(none)* | Emulators + Flutter, auto-detect connected device |
| `--web` | Emulators + Flutter on Chrome |
| `--prod` | Flutter pointed at live Firebase (no emulators) |
| `--emulator-only` | Start emulators only — no Flutter. Use this when running integration or Jest tests in a second terminal. |

### `./setup.sh` — first-time dependency install

Runs `flutter pub get`, `dart run build_runner build`, and `npm install` in one step. Re-run after pulling a branch that adds new packages.

### `cd functions && npm test` — Cloud Functions integration tests

Runs the full Jest suite against the local emulators. Requires emulators to be up first (`./dev.sh --emulator-only` in another terminal).

```bash
# Terminal 1 — start emulators
./dev.sh --emulator-only

# Terminal 2 — run tests
cd functions && npm test
```

The suite covers matchmaking (group rooms, 1v1 pool, priority selection, padding lifecycle, concurrent joins) and chat (message encryption, TTL fields, privacy-by-design cleanup, session key archiving).

### `cd apps/mobile && flutter test` — Flutter unit + widget tests

Runs all 1109 unit and widget tests for the Flutter app (domain, data, and presentation layers). No emulators needed — all Firebase calls are faked.

### `cd apps/mobile && flutter test integration_test/...` — Flutter integration tests

Runs Flutter-side integration tests against the emulators. Requires emulators running.

```bash
./dev.sh --emulator-only &
cd apps/mobile && flutter test integration_test/matchmaking_advanced_test.dart
```

### `./tools/check-prod-config.sh` — post-deploy production verification

Run this after every `firebase deploy` to verify the live project is correctly wired. Checks:

- Firestore TTL policies are **ACTIVE** on `chat_rooms/*/messages` and `session_keys` (3-day retention)
- All 15 Cloud Functions are deployed in the correct regions
- `expireRooms` scheduled function exists
- Prints a manual checklist for things that can't be automated (Cloud Scheduler enabled, `onDisconnect` behaviour, auth providers)

```bash
./tools/check-prod-config.sh
# or with a different project:
./tools/check-prod-config.sh --project my-project-id
```

Auth is automatic: the script picks up your `gcloud auth login` session, or falls back to your `firebase login` token. Run `gcloud auth login` or `firebase login` if neither has been done.

### `cd functions && npm run deploy` — deploy Cloud Functions to production

Runs lint + build first (via predeploy hooks in `firebase.json`). Deploy everything:

```bash
firebase deploy          # deploy functions + rules + indexes
firebase deploy --only functions   # functions only
firebase deploy --only firestore   # rules + indexes only
```

### `dart run build_runner build` — regenerate Freezed/Riverpod code

Run from `apps/mobile/` after editing any `@freezed` class or `@riverpod` provider:

```bash
cd apps/mobile && dart run build_runner build --delete-conflicting-outputs
```

---

## Emulator ports

When running with emulators:

| Service | Port | UI |
|---|---|---|
| Emulator UI | 4000 | http://127.0.0.1:4000 |
| Auth | 9099 | — |
| Firestore | 8080 | — |
| Realtime Database | 9000 | — |
| Functions | 5001 | — |
| Pub/Sub | 8085 | — |

---

## Switching between main UI and backend test screen

Open `apps/mobile/lib/main.dart` and change the compile-time constant on line 30:

```dart
const _useMainUI = false;  // backend test screen (HelloScreen → matchmaking buttons)
const _useMainUI = true;   // full app UI
```

Hot reload won't pick this up — do a full restart (`R` in terminal or re-run `./dev.sh`).

---

## Manual commands

```bash
# ── Flutter ──────────────────────────────────────────────────────────────────
cd apps/mobile
flutter pub get
dart run build_runner build          # regenerate @freezed / @riverpod code
flutter run                          # Android
flutter run -d chrome                # Web
flutter run --dart-define=USE_EMULATOR=false   # against production
flutter test                         # unit + widget tests
flutter analyze                      # static analysis

# ── Cloud Functions ───────────────────────────────────────────────────────────
cd functions
npm install
npm run build         # compile TypeScript
npm run lint          # ESLint
npm test              # Jest integration tests (needs emulators)
npm run deploy        # deploy to Firebase (lint + build run first)
```

---

## CI / quality gates

Every push runs two GitHub Actions jobs:

| Job | What it checks |
|---|---|
| `flutter-quality` | build_runner up to date, dart format, flutter analyze, flutter test --coverage |
| `functions-quality` | ESLint, TypeScript build, Jest integration tests (starts emulators automatically) |

The pre-push git hook runs the same checks locally before any push reaches GitHub.

---

## Project layout

```
apps/mobile/        Flutter app (Android + Web)
functions/          Firebase Cloud Functions (TypeScript)
  src/matchmaking/  Matchmaking CFs + Jest tests
  src/chat/         Chat CFs + Jest tests
  src/dev/          One-time setup helpers (remove after use)
tools/              Utility scripts
  check-prod-config.sh  Post-deploy production verification
packages/           Shared packages (reserved)
```

See [`CLAUDE.md`](./CLAUDE.md) for architecture details, code conventions, and the full feature guide.
See [`PROJECT_CONTEXT.md`](./PROJECT_CONTEXT.md) for database schema, security rules, and Firebase configuration.
