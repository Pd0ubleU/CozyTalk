# CozyTalk — Project Context

> Full project reference. Read before answering any questions about this project.

---

## What is CozyTalk?

CozyTalk is a **cross-platform stranger chat app** targeting **Android and Web**. Users are matched anonymously with a random stranger for a one-on-one text conversation. The goal is to provide a low-pressure space for authentic interactions — combating social media performance fatigue.

**Core Privacy Principle:** Chats are ephemeral. When a user leaves or presses Skip, the room and all messages are immediately destroyed by a Cloud Function. The only exception is when a user files a report — in that case the chat log is retained for moderation.

---

## Tech Stack

### Flutter App (`apps/mobile/`) — Android + Web
| Concern | Package |
|---|---|
| State management | `flutter_riverpod` 3.3.1 + `riverpod_annotation` (code-gen) |
| Navigation | `MaterialApp.routes` + `AppRoutes` constants (`theme/app_routes.dart`). `go_router` is in `pubspec.yaml` but never imported or used. |
| Firebase | `firebase_core`, `firebase_auth`, `cloud_functions`, `cloud_firestore`, `firebase_database`, `firebase_crashlytics`, `firebase_remote_config` |
| Local database | `sqflite` (Android only; web loads from bundled JSON) |
| Observability | Structured CF logging (`firebase-functions/logger`); Crashlytics for Flutter fatal/non-fatal errors (disabled in emulator mode) |
| Models | `freezed` + `json_serializable` (code-gen) |
| Auth | `google_sign_in` |
| Local caching | `flutter_secure_storage` · `shared_preferences` (profile + avatar offline cache via `ProfileCacheDatasource` / `AvatarCacheDatasource`) |
| Connectivity | `connectivity_plus ^7.x` (online/offline state detection via `NetworkInfo` abstraction + `isOnlineProvider`) |
| HTTP | `http` ^1.6.0 |
| Jukebox embed player | `webview_flutter` ^4.0.0 — Audiomack iframe on Android + Web |
| URL launching | `url_launcher` |

### Cloud Functions (`functions/`)
- TypeScript, Firebase Functions v2
- 25 functions exported across two regions (see Cloud Functions table in Firebase Configuration)
- Max 10 instances (cost control)
- Matchmaking and chat logic **must** live here — never on client

### Firebase Project
- **Project ID:** `cozytalk-5d984`
- **Region:** `us-central1` (Functions), `asia-southeast1` (Realtime DB)

---

## Architecture: Clean Architecture (feature-first)

```
features/<feature>/
├── domain/           ← Pure Dart. No Flutter, no Firebase.
│   ├── entities/     ← Plain data types
│   ├── repositories/ ← Abstract interfaces
│   └── usecases/     ← One class per operation
├── data/             ← Firebase/HTTP/serialization
│   ├── models/       ← @freezed DTOs + toEntity()
│   ├── datasources/  ← Raw SDK calls only
│   └── repositories/ ← Interface impl + DTO→Entity
└── presentation/     ← UI
    ├── providers/     ← Riverpod DI + Notifier + State
    └── screens/       ← ConsumerStatefulWidget pages
```

See `CLAUDE.md` for full conventions and code patterns.

---

## App Screens & User Flow

```
Login Screen
    ├── [Email + Password] ──────────────────────────────────┐
    ├── [Sign in with Google] ───────────────────────────────┤
    ├── [Continue as Guest] ───────────────────────────────── authenticated
    └── [Don't have an account?] → Sign Up Screen ───────────┘
            ↓
Waiting / Searching  ←──────────────────────────┐
    ↓  [matched by Cloud Function]               │
Chat Room                                        │
    ├── [Skip / Next Person] ────────────────────┘
    ├── [Leave] → session destroyed
    └── [Report] → chat log retained, session destroyed
Profile / Settings (planned)
    ├── Edit display name
    ├── Upgrade from anonymous → Google / Email
    └── Sign out
```

### Chat Room UI Components
- Message bubbles (sent / received)
- Typing indicator
- **Moods / Drinks SVG icebreakers** — tappable stickers
- **Skip / Next Person** button (prominent — core UX)
- Connection status indicator

### Session State Machine
```
Idle → Searching → Matched/Chatting → Disconnected
                                    ↘ (Skip) → Searching
```
The chat Notifier must model all four states explicitly as an enum — never infer from nullable fields.

---

## What Is Already Built

### `hello` feature (proof-of-concept, complete)
End-to-end clean arch example: `HelloScreen` → `HelloNotifier` → `CallHello` usecase → `HelloRepositoryImpl` → `HelloDatasourceImpl` → `helloWorld` Cloud Function → response flows back. This is the **primary template** for all future features.

### `auth` feature (complete)
Full authentication flow following the same Clean Architecture pattern.

**Domain:** `AuthUser` entity, `AuthRepository` interface, use cases: `SignUp`, `SignIn`, `SignOut`, `SignInAnonymously`, `SignInWithGoogle`.

**Data:** `AuthUserModel` (`@freezed` DTO), `AuthDatasourceImpl` (Firebase Auth + Firestore writes), `AuthRepositoryImpl`. Platform-specific Google sign-in: `signInWithPopup` on web, `google_sign_in` SDK on native.

**Presentation:**
- `AuthStatus` enum: `idle | loading | authenticated | unauthenticated`
- `AuthState` with sentinel `copyWith` for `user` and `error`
- `AuthNotifier` watching `FirebaseAuth.authStateChanges()` via the repository stream
- `LoginScreen` — email/password form + "Sign in with Google" + "Continue as Guest"
- `SignupScreen` — email/password/confirm form; pops to root on success

**Firestore user doc** is created by the datasource on `signUp` and on first-time Google sign-in (`additionalUserInfo.isNewUser == true`). Anonymous users get a minimal doc on first sign-in (uid, role, createdAt, lastSeen).

### `matchmaking` feature (complete)
Full Clean Architecture feature for joining the waiting pool, creating/joining rooms, and watching for a match. See [`CLAUDE.md` Matchmaking section](CLAUDE.md) and [`MATCHMAKING_CONTEXT_AWARE.md`](MATCHMAKING_CONTEXT_AWARE.md) for details.

### `chat` feature (complete)
In-session messaging layer. Handles AES-256-GCM message decryption, streaming messages and typing indicators, and session teardown. Works with both proto-sessions (client-side encryption) and 1v1 sessions (Cloud Function encryption). See [`CLAUDE.md` Chat Feature section](CLAUDE.md).

### `profile` feature (complete)
Read and update user profile fields (`displayName`, `interest`, `thoughts`) in `users/{uid}`. See [`CLAUDE.md` Profile Feature section](CLAUDE.md).

### `avatar` feature (complete)
Hat and mood overlay selection for the in-chat avatar. Reads/writes `hatKey` and `moodKey` fields in `users/{uid}`. See [`CLAUDE.md` Avatar Feature section](CLAUDE.md).

### `card_shuffle` feature (prototype)
Icebreaker question deck for conversation starters in chat rooms. Reads 100 questions from `assets/icebreaker-questions.json`, implements a remaining/seen exhaustion-before-repeat deck with depth warm-up (first 5 draws are light/medium only, deep unlocks after). State persisted in `SharedPreferences` (= `localStorage` on web). See [`docs/features/card_shuffle.md`](docs/features/card_shuffle.md).

**Prototype UI:** A `_TopicPanel` widget is embedded in `features/chat/presentation/screens/chat_screen.dart` — toggled by an "Icebreaker Topic" AppBar button. Not wired to server-side messaging.

### `word_filter` feature (complete)
Client-side profanity filter. Loads `assets/banned_words.json` into SQLite on Android (web reads the asset directly via `rootBundle`). Exposes a stateless `CensorText` use case that replaces matched EN and TH words with asterisks. Entirely gated by `content_filtering_enabled` Firebase Remote Config flag (default `false`). See [`docs/features/word_filter.md`](docs/features/word_filter.md).

### `home` feature (stub)
Navigation hub `HomeScreen`. Used only when `_useMainUI = true`. No domain/data layers — intentionally thin.

### App bootstrap (`lib/main.dart`)
Initialises Firebase, points to emulators (Auth `9099`, Functions `5001`, Firestore `8080`) when `USE_EMULATOR=true`. No automatic sign-in — `_AuthRouter` widget watches `authNotifierProvider` and routes to `LoginScreen` or `HelloScreen`.

### Tests
1115 Flutter unit + widget tests across auth, chat, matchmaking, profile, hello, admin, block, friends, card_shuffle, avatar, word_filter, and screens features (includes WCAG 2.2 AA accessibility tests for all 17 production screens). See [Test Coverage](#quality-gates-definition-of-done) for the full breakdown.

---

## Firebase Configuration

### Authentication — enabled providers
| Provider | Status |
|---|---|
| **Anonymous** | On. Wired in Flutter — "Continue as Guest" button on `LoginScreen`. |
| **Google Sign-In** | On. Wired in Flutter — web uses `signInWithPopup`, native uses `google_sign_in` SDK. |
| **Email / Password** | On. Passwordless OFF. Wired in Flutter — `LoginScreen` + `SignupScreen`. |
| **Biometric / Passkey** | Planned — Android Keystore + WebAuthn. Not yet implemented. |

### Firestore Security Rules — `firestore.rules` (deployed ✓)

See `firestore.rules` for the canonical source. Key helper functions and per-collection rules:

**Helper functions:**
- `isSignedIn()` — `request.auth != null`
- `isOwner(uid)` — signed in and `request.auth.uid == uid`
- `isAdmin()` — signed in + `users/{uid}.role == 'admin'`
- `_isRoomsParticipant(sessionId)` — uid in `rooms/{sessionId}.users`
- `_isActiveSessionParticipant(sessionId)` — uid in `active_sessions/{sessionId}.users`
- `isChatRoomParticipant(sessionId)` — either of the above (spans new rooms + legacy sessions)

**Per-collection rules summary:**

| Collection | read | create | update | delete |
|---|---|---|---|---|
| `users/{userId}` | any signed-in user (friends search) | owner; `role=='user'`, `uid==userId`, known-field allowlist (no email) | owner; `role`, `uid`, `createdAt` immutable; only `hatKey`, `moodKey`, `displayName`, `photoUrl`, `lastSeen`, `interest`, `thoughts` | — |
| `waiting_pool/{userId}` | owner | owner; `createdAt==request.time`, `status=='waiting'`, required keys present | owner; only `updatedAt` field, must equal `request.time` | owner |
| `rooms/{roomId}` | member or expired tombstone (any signed-in) | false (CF only) | member on custom room; only `isLocked` field | false |
| `active_sessions/{sessionId}` | member or `proto-*` prefix (any signed-in) | false | false | false |
| `reports/{reportId}` | admin only | signed-in; `reporterId==uid`, `status=='pending'`, required fields | admin only | admin only |
| `chat_rooms/{sessionId}/messages/{messageId}` | participant or `proto-*` | participant; required encrypted fields, `senderId==uid`, text ≤12 KB | false | false |

### Realtime Database — `database.rules.json` (deployed ✓)

**URL:** `https://cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app`

See `database.rules.json` for the canonical source. All nodes require `auth != null` at minimum.

| Node | Value | Access | Notes |
|---|---|---|---|
| `rooms/{roomId}/members/{uid}` | boolean | Read: room member; Write: owner | CF-written membership anchor for new rooms |
| `typing/{roomId}/{uid}` | `{ isTyping: bool, displayName: string, photoUrl?: string }` | Read: room member; Write: owner | `displayName` max 100 chars; `photoUrl` optional max 500 chars; unknown fields rejected |
| `presence/{roomId}/{uid}` | string (displayName) | Read: room member; Write: owner | Max 30 chars; `onDisconnect().remove()` |
| `nameQueue/{roomId}` | any | Read/Write: room member only | Transient display name exchange on room join |
| `user_status/{uid}` | `{ status, roomId?, roomMode? }` | Read/Write: owner only | `status`: `'online'`\|`'in_room'`; `roomId` 5 chars; `roomMode` `'1v1'`\|`'group'` |
| `pool_presence/{uid}` | boolean | Read/Write: owner | Tracks whether user is actively in the waiting pool |
| `jukebox/{roomId}` | `{ isPlaying, currentIndex, startedAt, queue[] }` | Read/Write: room member | Synced music queue; cleared by `endSession` CF |

### Firestore Indexes — `firestore.indexes.json` (deployed ✓)

| Collection | Fields | Query |
|---|---|---|
| `waiting_pool` | `status ASC, createdAt ASC` | Legacy: oldest waiting user (no mode filter) |
| `waiting_pool` | `mode ASC, status ASC, createdAt ASC` | Matchmaking: oldest waiting user by mode |
| `waiting_pool` | `mode ASC, status ASC, updatedAt ASC` | Matchmaking: most-recently-updated waiting user by mode |
| `reports` | `status ASC, createdAt DESC` | Admin dashboard: pending reports by time |
| `rooms` | `mode ASC, status ASC, isLocked ASC, memberCount ASC` | Group room picker: available unlocked rooms by fill level |
| `rooms` | `status ASC, paddingUntil ASC` | `expireRooms` cron: find rooms past their padding window |

### Cloud Functions — deployed (25 total)

| Function | Trigger | Region | Module |
|---|---|---|---|
| `helloWorld` | callable | us-central1 | — |
| `joinGroupRoom` | callable | us-central1 | matchmaking |
| `createCustomRoom` | callable | us-central1 | matchmaking |
| `joinRoomById` | callable | us-central1 | matchmaking |
| `leaveRoom` | callable | us-central1 | matchmaking |
| `join1v1Pool` | callable | us-central1 | matchmaking |
| `cancel1v1Pool` | callable | us-central1 | matchmaking |
| `setRoomLock` | callable | us-central1 | matchmaking |
| `expireRooms` | scheduled (`*/2 * * * *`) | us-central1 | matchmaking |
| `match1v1Users` | Firestore onCreate `waiting_pool/{uid}` | asia-southeast1 | matchmaking |
| `cleanupMember` | RTDB onDelete `rooms/{roomId}/members/{uid}` | asia-southeast1 | matchmaking |
| `cleanupPoolMember` | RTDB onDelete `pool_presence/{uid}` | asia-southeast1 | matchmaking |
| `sendMessage` | callable | us-central1 | chat |
| `endSession` | callable | us-central1 | chat |
| `reportSession` | callable | us-central1 | chat |
| `onFriendshipCreated` | Firestore onCreate `friendships/{friendshipId}` | us-central1 | friends |
| `onFriendshipDeleted` | Firestore onDelete `friendships/{friendshipId}` | us-central1 | friends |
| `adminGetDashboard` | callable (admin only) | us-central1 | admin |
| `adminResolveReport` | callable (admin only) | us-central1 | admin |
| `adminGetChatLog` | callable (admin only) | us-central1 | admin |
| `adminBanUser` | callable (admin only) | us-central1 | admin |
| `adminUnbanUser` | callable (admin only) | us-central1 | admin |
| `adminGetBlockedUsers` | callable (admin only) | us-central1 | admin |
| `blockUser` | callable | us-central1 | user |
| `unblockUser` | callable | us-central1 | user |
No CF needed for typing — clients write `typing/{roomId}/{uid}` directly via RTDB SDK.

`seedTtlCollections` (`functions/src/dev/`) is a one-time dev HTTP helper; not included in the exported count above.

`onProtoPresenceDeleted` (`functions/src/chat/`) is an RTDB trigger for proto-session presence cleanup; internal, not exported.

### Feature Flags — Firebase Remote Config

`icebreakers_enabled` (boolean, default `true`) — gates the Moods/Drinks SVG sticker panel.
Rollback: set to `false` in Remote Config console; clients pick it up within 12 hours.

`content_filtering_enabled` (boolean, default `false`) — gates the word filter / censor feature. When `false`, `censorTextProvider` passes text through unchanged. The app-side default is `false` (filter disabled); set to `true` in the Remote Config console to enable.
Rollback: set to `false` in Remote Config console; clients pick it up within 1 hour (minimum fetch interval). No release required.

---

## Database Schema (Finalized)

### `users/{uid}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `uid` | string | matches auth UID; immutable |
| `displayName` | string? | null for anonymous |
| `photoUrl` | string? | null for anonymous |
| `role` | string | `'user'` \| `'admin'`; immutable after creation |
| `createdAt` | timestamp | immutable after creation |
| `lastSeen` | timestamp | updated on profile refresh |
| `hatKey` | string? | avatar hat decoration key; absent = no hat |
| `moodKey` | string? | avatar mood decoration key; absent = no mood |
| `interest` | string? | user's free-text interest (used for embedding-based matchmaking) |
| `thoughts` | string? | short status/mood text; max 50 chars |

Anonymous users get a minimal doc on first sign-in (`uid`, `role: 'user'`, `createdAt`, `lastSeen`) to prevent `isAdmin()` from throwing. The avatar datasource will also create this minimal doc (plus the decoration field) if it doesn't exist yet.

### `waiting_pool/{uid}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `createdAt` | timestamp | must be `request.time` (rules enforced) |
| `status` | string | `'waiting'` → `'matching'` → `'matched'` (CF-managed) |
| `updatedAt` | timestamp | client-updatable only |
| `mode` | string | `'1v1'` \| `'group'` |
| `roomId` | string? | set by CF when matched (1v1 only) |

### `rooms/{roomId}` (Firestore) — Primary Room Collection
All new rooms (1v1 + group). Doc ID is the 5-char user-facing room ID. CF-only writer except `isLocked` on custom rooms. Expired rooms keep a tombstone forever to prevent ID reuse.

| Field | Type | Notes |
|---|---|---|
| `roomId` | string | 5-char alphanumeric, matches doc ID |
| `roomType` | string | `'public'` \| `'custom'` |
| `mode` | string | `'1v1'` \| `'group'` |
| `status` | string | `'active'` \| `'padding'` \| `'expired'` |
| `maxUsers` | number | `2` for 1v1, `5` for group |
| `memberCount` | number | 0–maxUsers |
| `users` | string[] | current member UIDs |
| `isLocked` | boolean | custom rooms only; participants update directly via rules |
| `createdAt` | timestamp | server timestamp |
| `paddingUntil` | timestamp? | set when last user leaves; `expireRooms` cron cleans up after |
| `encryptionKey` | string | hex AES-256 key, generated at room creation |

Expired tombstone shape: `{ status: 'expired', expiredAt: Timestamp, users: [] }`

### `users/{uid}/blocked/{uid}` (Firestore)
Max 5 entries per user. Owner-only read/write enforced by security rules.

| Field | Type | Notes |
|---|---|---|
| `blockedUid` | string | UID of the blocked user |
| `displayName` | string? | display name snapshot at block time |
| `blockedAt` | timestamp | server timestamp |

### `active_sessions/{sessionId}` (Firestore) — Legacy
**Proto-session backward compat only.** New sessions use `rooms/{roomId}`.

| Field | Type | Notes |
|---|---|---|
| `users` | string[] | `[uid1, uid2]` — used by Firestore rules |
| `roomId` | string | equals `sessionId` |
| `createdAt` | timestamp | |
| `endedAt` | timestamp? | set on session end |
| `status` | string | `'active'` \| `'ended'` |

### `reports/{reportId}` (Firestore)
| Field | Type | Notes |
|---|---|---|
| `reporterId` | string | UID of reporting user |
| `reportedUserId` | string | UID of reported user |
| `sessionId` | string | session where it occurred |
| `reportType` | string | `spam` \| `harassment` \| `inappropriate_content` \| `other` |
| `reason` | string | max 500 chars |
| `contextText` | string? | optional free-text ≤2000 chars |
| `contextImageUrls` | string[] | Storage URLs of up to 5 screenshots uploaded by reporter |
| `chatLogStoragePath` | string? | path to `reports/{reportId}/chat_log.json` in Cloud Storage; null if Storage write failed; CF-written |
| `createdAt` | timestamp | |
| `status` | string | `pending` on creation; `reviewed` or `dismissed` after admin action |
| `outcome` | map? | written by admin CFs: `{ kind: "banned"\|"reviewed"\|"dismissed", by: uid, byName: string, at: timestamp, note: string? }` |

### `chat_rooms/{sessionId}/messages/{messageId}` (Firestore)
Encrypted message store. Written by the `sendMessage` CF. TTL policy on `expiresAt` auto-deletes messages after the retention window (3 days). Destroyed immediately by `leaveRoom`/`endSession` unless a report is pending.

| Field | Type | Notes |
|---|---|---|
| `senderId` | string | UID of sender |
| `displayName` | string | display name at time of send; max 200 chars |
| `encryptedText` | string | base64 AES-256-GCM ciphertext; max 12 KB |
| `iv` | string | base64 GCM IV; max 24 chars |
| `authTag` | string | base64 GCM auth tag; max 32 chars |
| `timestamp` | timestamp | server timestamp |
| `expiresAt` | timestamp | TTL field — Firestore auto-deletes after this |
| `flagged` | boolean | always `false` at creation; set by `reportSession` CF |

### `session_keys/{sessionId}` (Firestore)
Archives the AES-256 room encryption key so moderators can decrypt flagged messages within the 3-day retention window. Created by `endSession` CF. TTL policy on `expiresAt`.

| Field | Type | Notes |
|---|---|---|
| `sessionId` | string | matches doc ID |
| `encryptionKey` | string | hex AES-256 key |
| `users` | string[] | `[uid1, uid2]` |
| `createdAt` | timestamp | original session creation time |
| `expiresAt` | timestamp | 3 days after session end; TTL field |
| `flagged` | boolean | set to `true` by `reportSession` to prevent premature TTL deletion |

### RTDB Real-time Paths
See the RTDB rules table above (under Firebase Configuration) for the full path list with access controls. Summary:

| Path | Purpose |
|---|---|
| `rooms/{roomId}/members/{uid}` | CF-written membership anchor (new rooms) |
| `typing/{roomId}/{uid}` | Real-time typing indicator |
| `presence/{roomId}/{uid}` | Real-time presence; `onDisconnect().remove()` |
| `nameQueue/{roomId}` | Transient display name exchange on room join |
| `pool_presence/{uid}` | Whether user is actively in the waiting pool |

Presence, typing, and nameQueue data are removed by `leaveRoom` CF on explicit leave and by `expireRooms` on room expiry. `cleanupMember` (RTDB trigger) fires when a `rooms/{roomId}/members/{uid}` node is deleted to handle abrupt disconnects.

---

## Development Phases (WBS)

| Phase | Work | Status |
|---|---|---|
| **1.0 Frontend & UI** | UI/UX design, Auth screens, Waiting screen, Chat Room UI (bubbles, typing, SVGs, Skip) | Auth complete; main UI screens complete (not yet wired to backend) |
| **2.0 Backend & Matchmaking** | Matchmaking Cloud Functions (race-condition safe), session cleanup/lifecycle, word censor, reporting | **Largely complete** — 25 CFs exported (matchmaking + chat + friends + admin + user); Flutter matchmaking + chat + avatar + profile + word_filter features complete; 172 Jest unit tests + 43 Flutter integration tests passing; group reporting deferred |
| **3.0 Logic & Integration** | Wire main UI to matchmaking backend, session state machine, network drop detection, biometric/passkey auth | Not started |
| **4.0 Testing & Management** | Cross-platform UI tests (Android + Web), accessibility sweeps, performance profiling | Not started |

---

## Quality Gates (Definition of Done)

| Gate | Requirement |
|---|---|
| **Correctness** | >80% unit test coverage for domain layer; widget tests for all screens; integration tests on Android + Web |
| **Security** | Zero High/Critical vulnerabilities; secret scan clean; no plaintext secrets |
| **Accessibility** | WCAG 2.2 AA on all screens (semantic labels, contrast, dynamic type) |
| **Performance** | No unbounded ListViews; SVGs cached/compressed; no jank on message scroll |

### Test Coverage (~450+ tests total)

| Suite | Count | Location | Requires |
|---|---|---|---|
| Flutter unit + widget | 1115 tests | `apps/mobile/test/` | Nothing |
| Cloud Functions Jest | 172 unit tests | `functions/src/**/__tests__/*.test.ts` | `./dev.sh --emulator-only` |
| Cloud Functions Jest (integration) | 7 live tests | `functions/src/matchmaking/__tests__/embeddingService.integration.test.ts` | Vertex AI credentials + `npm run test:embedding` |
| Flutter integration | 43 tests | `apps/mobile/integration_test/matchmaking_advanced_test.dart` | Emulators + Android device |

**CF Jest unit test breakdown:** `matchmaking.test.ts` (82 tests — priority selection, distribution, padding lifecycle, RTDB cleanup, 1v1/group flows, interest matching, background-theme partitioning), `admin.test.ts` (32 tests — dashboard, resolve report, chat log, ban/unban), `embeddingService.test.ts` (21 tests — cosine similarity, mean vector, mocked Vertex AI), `block.test.ts` (20 tests — blockUser, unblockUser, adminGetBlockedUsers, max-5 enforcement, idempotency), `chat.test.ts` (12 tests — sendMessage, message destruction, TTL, rooms/ path, reportSession), `friends.test.ts` (5 tests — onFriendshipCreated/onFriendshipDeleted: message cleanup, RTDB friends node removal, graceful no-users handling). Plus 7 integration tests in `embeddingService.integration.test.ts` (live Vertex AI, requires `npm run test:embedding`). Grand total: 179.

**Flutter word_filter tests (14):** `banned_word_test.dart` (2), `censor_text_test.dart` (3), `banned_word_model_test.dart` (5), `word_filter_repository_impl_test.dart` (2), `word_filter_provider_test.dart` (2).

**Jest vs Flutter integration:** Jest tests run on the host (no Android clock skew) so timing bounds are tight (≤35s padding). Flutter integration tests use ≤60s bounds to account for Android emulator clock offset.

---

## The Do-Not-Do List

| ❌ Never | Reason |
|---|---|
| Import Flutter/Firebase into domain layer | Clean arch violation |
| Matchmaking on client | Race conditions |
| Persist chat messages | Privacy by Design |
| Hand-roll toJson/fromJson | Use Freezed |
| Store secrets in SharedPreferences, Drift, Hive, or assets | Extractable from APK/IPA |
| Edit `*.g.dart` / `*.freezed.dart` | Run build_runner instead |
| Unbounded `ListView(children: [...])` for dynamic data | Performance |

---

## Repository Layout

```
CozyTalk/
├── apps/mobile/                      ← Flutter app (Android + Web)
│   ├── lib/
│   │   ├── main.dart                 ← Firebase init, emulator setup, _AuthRouter
│   │   ├── features/
│   │   │   ├── hello/                ← proof-of-concept template (complete)
│   │   │   ├── auth/                 ← authentication (complete; LoginScreen, SignupScreen)
│   │   │   ├── matchmaking/          ← room joining + 1v1 pool (complete; 9 use cases)
│   │   │   ├── chat/                 ← in-session messaging + typing (complete; 5 use cases)
│   │   │   ├── profile/              ← display name, interest, thoughts (complete; 4 use cases)
│   │   │   ├── avatar/               ← hat + mood decoration (complete; 4 use cases; screen widget test pending)
│   │   │   ├── home/                 ← navigation hub stub (presentation only)
│   │   │   └── friends/              ← friend requests, friend list, permanent direct chat (prototype)
│   │   └── screens/                  ← legacy design-preview UI (not wired to features layer)
│   ├── test/                         ← 1092 unit + widget tests
│   └── .env.example                  ← committed; USE_EMULATOR=true by default
├── functions/src/
│   ├── index.ts                      ← exports 25 functions
│   ├── matchmaking/                  ← 11 exported CFs + embeddingService.ts + _utils.ts + __tests__/
│   ├── chat/                         ← sendMessage, endSession, reportSession (exported); onProtoPresenceDeleted (internal stub)
│   ├── admin/                        ← 6 admin CFs (dashboard, resolve, chat log, ban, unban, blocked users)
│   ├── friends/                      ← onFriendshipCreated, onFriendshipDeleted
│   ├── user/                         ← blockUser, unblockUser
│   └── dev/                          ← seedTtlCollections (one-time HTTP dev helper)
├── firestore.rules                   ← deployed Firestore security rules
├── database.rules.json               ← deployed RTDB security rules
├── firestore.indexes.json            ← Firestore composite indexes (6 indexes)
├── firebase.json                     ← Firebase deploy config (predeploy: npm --prefix functions)
├── .gitattributes                    ← enforces LF line endings repo-wide
├── .claude/agents/                   ← specialized agent definitions
├── CLAUDE.md                         ← auto-loaded by Claude Code every session
└── PROJECT_CONTEXT.md                ← this file
```


