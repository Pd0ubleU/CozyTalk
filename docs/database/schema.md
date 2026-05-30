# Database Schema

Full reference: `PROJECT_CONTEXT.md` (Firestore rules) and `MATCHMAKING_CONTEXT_AWARE.md` (interest matching).

---

## Firestore Collections

### `users/{uid}`

| Field | Type | Notes |
|---|---|---|
| `uid` | string | same as document ID |
| `role` | string | `'user'` or `'admin'` — immutable after creation |
| `createdAt` | timestamp | |
| `lastSeen` | timestamp | |
| `displayName` | string? | |
| `photoUrl` | string? | |
| `hatKey` | string? | avatar hat |
| `moodKey` | string? | avatar mood |
| `interest` | string? | free-text interest for matching |
| `thoughts` | string? | |
| `banned` | boolean? | present and `true` only while actively banned |
| `banReason` | string? | e.g. "Harassment or Bullying" |
| `banDuration` | string? | `"1 Day"` \| `"7 Days"` \| `"30 Days"` \| `"Permanent"` |
| `bannedAt` | timestamp? | |
| `banExpiresAt` | timestamp? | `null` for permanent ban |
| `bannedBy` | string? | admin uid |
| `bannedByName` | string? | admin displayName at time of ban |
| `banNote` | string? | optional moderator note |
| `banHistory` | array? | append-only log; each entry: `{ reason, duration, bannedAt, expiresAt, bannedBy, bannedByName, note, unbannedAt, unbannedBy }` |

Rules: read by any signed-in user (broadened from owner-only to support friends user-search). Create allowed for authenticated users (must include uid, role, createdAt, lastSeen — email is never stored in Firestore). Update allowed for own doc; `role`, `uid`, `createdAt` fields immutable.

### `waiting_pool/{uid}`

| Field | Type | Notes |
|---|---|---|
| `status` | string | `'waiting'` → `'matching'` → `'matched'` (CF-managed) |
| `mode` | string | `'1v1'` or `'group'` |
| `createdAt` | timestamp | server timestamp, must equal `request.time` (rules-enforced) |
| `updatedAt` | timestamp | client-updatable only |
| `interestText` | string? | raw interest text |
| `interestVector` | array? | 256-dim Vertex AI embedding |
| `roomId` | string? | set by `match1v1Users` CF when matched (1v1 only); `null` initially |
| `backgroundTheme` | string? | one of `kao_tapu`, `red_lotus_lake`, `sea_of_cloud`, `lumphini_park`; `null` = no theme filter |

Rules: update restricted to `updatedAt` field only (prevents client status manipulation).

### `rooms/{roomId}`

5-char alphanumeric room ID.

| Field | Type | Notes |
|---|---|---|
| `roomId` | string | document ID |
| `mode` | string | `'1v1'` or `'group'` |
| `roomType` | string | `'public'` (pool-matched) or `'custom'` (created with ID) |
| `status` | string | `'active'`, `'padding'`, `'expired'` |
| `users` | string[] | UIDs of participants |
| `memberCount` | number | |
| `maxUsers` | number | 2 for 1v1, up to 5 for group |
| `encryptionKey` | string | hex AES-256 key — readable by room members (used for client-side decryption) |
| `isLocked` | boolean | |
| `paddingUntil` | timestamp? | set when status transitions to `padding` |
| `createdAt` | timestamp | |
| `blockList` | array? | merged block list — each entry: `{ blockedBy: uid, userId: uid, amount: number }`. Updated on every join/leave; `amount` = count of current members blocking `userId` |
| `roomInterestVector` | number[]? | mean of all members' 256-dim Vertex AI interest embeddings; written by `joinGroupRoom` and `match1v1Users` CFs; used for group room cosine similarity matching |
| `backgroundTheme` | string? | one of `kao_tapu`, `red_lotus_lake`, `sea_of_cloud`, `lumphini_park`; absent when no theme was chosen; acts as hard partition key during matchmaking |

Rules: `users` membership checked for read/write access.

### `active_sessions/{id}`

Legacy proto-sessions only. New code uses `rooms/`. Not actively written to by current CFs.

### `chat_rooms/{sessionId}/messages/{messageId}`

| Field | Type | Notes |
|---|---|---|
| `senderId` | string | always set server-side from `request.auth.uid` |
| `displayName` | string | always sourced from Firestore users doc, never client payload |
| `encryptedText` | string | base64 AES-256-GCM ciphertext |
| `iv` | string | base64 12-byte random IV |
| `authTag` | string | base64 GCM auth tag |
| `timestamp` | timestamp | |
| `expiresAt` | timestamp | 3-day TTL (Firestore TTL policy) |
| `flagged` | boolean | `false` at creation; set to `true` by `reportSession` CF to preserve message for moderation |

Rules: create validates `senderId == request.auth.uid`. No client reads after session end.

### `session_keys/{sessionId}`

Archived encryption keys after session ends.

| Field | Type | Notes |
|---|---|---|
| `sessionId` | string | matches document ID |
| `encryptionKey` | string | hex AES-256 key |
| `users` | string[] | UIDs of room participants |
| `createdAt` | timestamp | original session creation time |
| `expiresAt` | timestamp | TTL — auto-deleted after retention window; cleared to `null` when flagged |
| `flagged` | boolean | set to `true` by `reportSession` to prevent premature TTL deletion |

Rules: deny all client access — admin SDK only.

### `friend_requests/{requestId}`

Pending, accepted, or declined friend requests.

| Field | Type | Notes |
|---|---|---|
| `fromUid` | string | sender UID |
| `fromDisplayName` | string | sender's display name at time of request |
| `toUid` | string | recipient UID |
| `toDisplayName` | string | recipient's display name at time of request |
| `status` | string | `'pending'` → `'accepted'` or `'declined'` |
| `createdAt` | timestamp | |

Rules: create by sender (must set `fromUid == uid`, `status == 'pending'`). Read by sender or recipient. Update by recipient only (status field only).

### `friendships/{friendshipId}`

One document per accepted friend pair. `friendshipId` = sorted UIDs joined with `_` (e.g. `uid1_uid2`).

| Field | Type | Notes |
|---|---|---|
| `users` | string[] | both UIDs |
| `displayNames` | map | `{uid: displayName}` for each user |
| `chatRoomId` | string | equals `friendshipId`; used as path to `friend_messages` |
| `createdAt` | timestamp | |

Rules: read and delete by members. Create by either member (written client-side in batch with accepted request).

### `friend_messages/{chatRoomId}/messages/{messageId}`

Permanent friend-to-friend chat messages. `chatRoomId` equals the `friendshipId`. Messages are **not** ephemeral — no TTL, no encryption (prototype plaintext).

| Field | Type | Notes |
|---|---|---|
| `senderId` | string | set from `request.auth.uid` |
| `senderDisplayName` | string | sender's display name |
| `text` | string | plaintext message body |
| `timestamp` | timestamp | server timestamp |

Rules: read/create by friendship participants (`_isFriendshipParticipant` helper checks `friendships/{chatRoomId}.users`). No update or delete.

### `reports/{id}`

| Field | Type | Notes |
|---|---|---|
| `reporterId` | string | set from `request.auth.uid` by CF |
| `reportedUserId` | string | validated to be an actual session participant |
| `sessionId` | string | |
| `reportType` | string | one of `spam`, `harassment`, `inappropriate_content`, `other` |
| `reason` | string | ≤500 chars |
| `contextText` | string? | optional free-text ≤2000 chars |
| `contextImageUrls` | string[] | Storage URLs of up to 5 screenshots uploaded by reporter |
| `chatLogStoragePath` | string? | path to `reports/{reportId}/chat_log.json` in Cloud Storage; null if Storage write failed |
| `createdAt` | timestamp | |
| `status` | string | `pending` on creation; `reviewed` or `dismissed` after admin action |
| `outcome` | map? | written by admin CFs: `{ kind: "banned"\|"reviewed"\|"dismissed", by: uid, byName: string, at: timestamp, note: string? }` |

Note: `encryptionKey` is NOT stored here — it lives exclusively in `session_keys/{sessionId}`. The decrypted chat log is in Cloud Storage at `chatLogStoragePath`.

Rules: any authenticated user may create (restricted: `reporterId == uid`, `status == 'pending'`, `reportType` validated, required fields only). Read, update, delete are admin-only.

### `users/{uid}/blocked/{blockedUid}`

Subcollection on each user document storing their explicit block list.

| Field | Type | Notes |
|---|---|---|
| `blockedUid` | string | = document ID — UID of the blocked user |
| `displayName` | string? | display name captured at time of blocking |
| `blockedAt` | timestamp | server timestamp |

Max 5 entries per user (enforced by `blockUser` CF). Owner read/write only.

---

## RTDB Paths

RTDB instance: `cozytalk-5d984-default-rtdb.asia-southeast1.firebasedatabase.app`

| Path | Read rule | Write rule | Purpose |
|---|---|---|---|
| `rooms/{roomId}/members/{uid}` | room members | room members | presence for room occupants |
| `typing/{roomId}/{uid}` | room members | own UID | typing indicator |
| `presence/{roomId}/{uid}` | room members | own UID | online presence (onDisconnect removes) |
| `nameQueue/{roomId}` | room members | room members | anonymous name assignment — defined in RTDB rules but not actively used in current mobile or CF code; reserved for a future feature |
| `pool_presence/{uid}` | own UID | own UID | pool presence (removed on disconnect) |
| `jukebox/{roomId}` | room members | room members | synced music queue state (see jukebox feature) |
| `user_status/{uid}` | own UID **or** friend of `$uid` (via `friends/{uid}/{auth.uid} === true`) | own UID | global online/in-room presence; `{ status: 'online'\|'in_room', roomId?: string, roomMode?: string }`; written by `OwnStatusNotifier` on auth and matchmaking state changes; node deleted entirely on sign-out |
| `friends/{ownerUid}/{friendUid}` | own `$ownerUid` | own `$ownerUid` | denormalized friendship flag (`true`) used by RTDB security rules to allow friends to read each other's `user_status`; written by `FriendsDatasourceImpl.acceptFriendRequest()` client-side; cleaned up by `onFriendshipDeleted` CF on `friendships` document delete |

Note: `cleanupMember` CF triggers on `rooms/{roomId}/members/{uid}` deletion. `cleanupPoolMember` triggers on `pool_presence/{uid}` deletion. `jukebox/{roomId}` is cleared by `endSession` CF when a session ends. `user_status/{uid}` is managed exclusively by `OwnStatusNotifier` on the client — no CF cleanup. `friends/{ownerUid}/{friendUid}` is cleaned up server-side by `onFriendshipDeleted` CF.

---

## Firestore Indexes

`firestore.indexes.json` — 8 composite indexes deployed:

| Collection | Fields | Purpose |
|---|---|---|
| `waiting_pool` | `status ASC, createdAt ASC` | Legacy: oldest waiting user (no mode filter) |
| `waiting_pool` | `mode ASC, status ASC, createdAt ASC` | Matchmaking: oldest waiting user by mode |
| `waiting_pool` | `mode ASC, status ASC, updatedAt ASC` | Matchmaking: most-recently-updated waiting user by mode |
| `reports` | `status ASC, createdAt DESC` | Admin dashboard: pending reports by time |
| `rooms` | `mode ASC, status ASC, isLocked ASC, memberCount ASC` | Group room picker: available unlocked rooms by fill level |
| `rooms` | `mode ASC, status ASC, isLocked ASC, backgroundTheme ASC, memberCount ASC` | Theme-filtered group room queries in `joinGroupRoom` (themed users only) |
| `rooms` | `status ASC, paddingUntil ASC` | `expireRooms` cron: find rooms past their padding window |
| `friend_requests` | `toUid ASC, status ASC` | Friends: incoming pending requests for a user |

TTL field policies (live in prod): `chat_rooms/{id}/messages.expiresAt` and `session_keys.expiresAt`.

---

## Security Rule Files

- `firestore.rules` — Firestore security rules
- `database.rules.json` — RTDB security rules
