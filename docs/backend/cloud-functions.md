# Cloud Functions

24 exported functions total. All in `functions/src/`. Deployed via Firebase CLI.

Firebase project: `cozytalk-5d984`
Default region: `us-central1` (unless noted)

---

## User (2 functions)

### `blockUser`
`functions/src/user/blockUser.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ targetUid: string, displayName?: string }`
- **Process:** Validates caller ≠ target. In a Firestore transaction, reads `users/{callerUid}/blocked/` and enforces the max 5 blocked users atomically (so concurrent calls cannot bypass the cap). If target is already blocked, idempotently updates `displayName`. Otherwise writes `{ blockedUid, displayName, blockedAt }` to `users/{callerUid}/blocked/{targetUid}`.
- **Output:** `{ success: true }` or `{ success: false, reason: "max_blocked_reached" }`

### `unblockUser`
`functions/src/user/unblockUser.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ targetUid: string }`
- **Process:** Deletes `users/{callerUid}/blocked/{targetUid}`. Idempotent — no error if not blocked.
- **Output:** `{ success: true }`

---

## Admin (6 functions)

All admin functions are callable, deployed to `us-central1`. Every function verifies the caller has `role == "admin"` in `users/{uid}` via admin SDK.

### `adminGetDashboard`
`functions/src/admin/adminGetDashboard.ts`
- **Trigger:** callable (admin only)
- **Input:** none
- **Process:** Parallel queries: (1) Firestore count on `reports/` where `status == "pending"`, (2) count unique UIDs across RTDB `pool_presence/` keys and Firestore `rooms` docs (`users` array field) where `status == "active"`, (3) Firestore count on `users/` where `banned == true`.
- **Output:** `{ pendingReports: number, onlineUsers: number, bannedUsers: number }`

### `adminResolveReport`
`functions/src/admin/adminResolveReport.ts`
- **Trigger:** callable (admin only)
- **Input:** `{ reportId: string, action: "dismiss" | "reviewed", note?: string }`
- **Process:** Reads report; rejects if `status != "pending"`. Updates `status` and writes `outcome` object with `kind`, `by`, `byName`, `at`, `note`.
- **Output:** `{ success: true }` or `{ success: false, reason: "not_found" | "already_resolved" }`

### `adminGetChatLog`
`functions/src/admin/adminGetChatLog.ts`
- **Trigger:** callable (admin only)
- **Input:** `{ reportId: string }`
- **Process:** Reads `reports/{reportId}`. If `chatLogStoragePath` is present, generates a 15-minute signed URL from Cloud Storage. In emulator mode returns a direct download URL.
- **Output:** `{ signedUrl: string, expiresAt: string }` or `{ success: false, reason: "not_found" | "no_chat_log" }`

### `adminBanUser`
`functions/src/admin/adminBanUser.ts`
- **Trigger:** callable (admin only)
- **Input:** `{ uid: string, reason: string, duration: "1 Day" | "7 Days" | "30 Days" | "Permanent", note?: string, reportId?: string }`
- **Process:** Verifies user exists and is not already banned. Writes ban fields to `users/{uid}` (`banned`, `banReason`, `banDuration`, `bannedAt`, `banExpiresAt`, `bannedBy`, `bannedByName`, `banNote`). If `reportId` provided, atomically sets `reports/{reportId}.status = "reviewed"` and writes `outcome.kind = "banned"` in the same batch.
- **Output:** `{ success: true }` or `{ success: false, reason: "user_not_found" | "already_banned" }`

### `adminUnbanUser`
`functions/src/admin/adminUnbanUser.ts`
- **Trigger:** callable (admin only)
- **Input:** `{ uid: string, note?: string }`
- **Process:** Reads user; rejects if not banned. Builds a history record from current ban fields (including `unbannedAt: Timestamp.now()`, `unbannedBy: callerUid`). Deletes all active ban fields from `users/{uid}`. Appends history record to `users/{uid}.banHistory` via `FieldValue.arrayUnion`.
- **Output:** `{ success: true }` or `{ success: false, reason: "user_not_found" | "not_banned" }`

### `adminGetBlockedUsers`
`functions/src/admin/adminGetBlockedUsers.ts`
- **Trigger:** callable (admin only)
- **Input:** `{ uid: string }`
- **Process:** Reads `users/{uid}/blocked/` subcollection ordered by `blockedAt` descending. Returns serialized list with `blockedAt` as ISO string.
- **Output:** `{ blockedUsers: Array<{ uid, displayName, blockedAt }> }`

---

## Chat (3 functions)

### `sendMessage`
`functions/src/chat/sendMessage.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ sessionId: string, text: string }`
- **Process:** Looks up room in `rooms/{sessionId}` then `active_sessions/{sessionId}`. Verifies caller is participant. Encrypts text with AES-256-GCM (random 12-byte IV). Writes to `chat_rooms/{sessionId}/messages`.
- **Output:** `{ messageId: string }`

### `endSession`
`functions/src/chat/endSession.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ sessionId: string }`
- **Process:** Looks up `rooms/{sessionId}` then `active_sessions/{sessionId}`. Verifies caller is participant. Archives key to `session_keys/{sessionId}`. Tombstones room (`status: expired`). Deletes RTDB presence/typing/jukebox for room. Deletes `chat_rooms/{sessionId}/messages`.
- **Output:** `{ success: true }`

### `reportSession`
`functions/src/chat/reportSession.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ sessionId, reportedUserId, reportType, reason, contextText?, contextImageUrls? }`
- **Process:** Validates all inputs (`reason` ≤500 chars, `contextText` optional ≤2000 chars, `reportType` one of `spam|harassment|inappropriate_content|other`, `contextImageUrls` ≤5 Firebase Storage URLs (`https://firebasestorage.googleapis.com/` prefix required), no self-reporting). Verifies both `reporterId` **and** `reportedUserId` are actual session participants. Looks up `encryptionKey` from `rooms/{sessionId}` (falls back to `active_sessions`, then `session_keys`). Upserts `session_keys/{sessionId}` with `flagged: true, expiresAt: null`. Decrypts all messages (AES-256-GCM), sorts by timestamp, saves plaintext to `reports/{reportId}/chat_log.json` in Cloud Storage (non-fatal if Storage write fails). Batch-updates `chat_rooms/{sessionId}/messages` with `{flagged: true, expiresAt: null}`. Creates `reports/{auto-id}` in Firestore (no `encryptionKey` in the doc — key remains in `session_keys/` only). Room is NOT ended — caller should call `endSession` after.
- **Output:** `{ reportId: string }`

---

## Matchmaking (11 functions)

### `join1v1Pool`
`functions/src/matchmaking/join1v1Pool.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ interestText?: string, backgroundTheme?: string }`
- **Process:** Adds user to `waiting_pool/{uid}` with `status: waiting`. If `interestText` provided, generates embedding via Vertex AI and stores 256-dim vector; if Vertex AI is unavailable or rate-limited the error is caught and the user joins with `interestVector: null`, falling back to random matching. If `backgroundTheme` provided, validates against the four allowed IDs (`kao_tapu`, `red_lotus_lake`, `sea_of_cloud`, `lumphini_park`) — invalid values are silently dropped to `null`. Sets `pool_presence/{uid}` in RTDB.
- **Output:** `{ success: true }`

### `cancel1v1Pool`
`functions/src/matchmaking/cancel1v1Pool.ts`
- **Trigger:** callable (authenticated)
- **Input:** none
- **Process:** Removes user from `waiting_pool`. Clears `pool_presence` RTDB node.
- **Output:** `{ success: true }` or `{ success: false, reason: "matching_in_progress" }` if already matching

### `match1v1Users`
`functions/src/matchmaking/match1v1Users.ts`
- **Trigger:** Firestore `onDocumentCreated` — `waiting_pool/{uid}` — **region: `asia-southeast1`**
- **Process:** 2-phase atomic Firestore transaction over a window of up to **20** candidates. Filters out candidate pairs where either user has blocked the other (read cost: 1 + N block-list subcollection reads). If the triggering user has a `backgroundTheme`, also hard-filters candidates to same-theme or unthemed users (unthemed = flexible, adopts the room's theme); the only blocked pairing is two users with different non-null themes, and unthemed triggers match anyone. Finds best candidate by cosine similarity of interest vectors (threshold 0.65). Creates `rooms/{roomId}` with `mode: 1v1`, `status: active`, and `backgroundTheme` always written (valid string or `null`). Removes both users from pool. Writes match result to RTDB. **Error recovery:** if Phase 2 (room creation) or Phase 3 (finalization) fails, cleanup writes rethrow on failure rather than swallowing — prevents a candidate from being permanently stuck in `"matching"` status if a secondary write fails mid-cleanup.
- **Output:** void (trigger)

### `joinGroupRoom`
`functions/src/matchmaking/joinGroupRoom.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ interestText?: string, backgroundTheme?: string }`
- **Process:** 3-phase match: find candidate group rooms → compute cosine similarity → join best match or create new group room. If `backgroundTheme` is provided, Firestore queries are filtered to same-theme rooms only (themed users never land in a different-theme room); unthemed users see all rooms and may join themed rooms. Room capacity 2–5 users. `backgroundTheme` is always written on created rooms (valid string or `null`). Before joining, fetches the caller's blocked list and rejects the join if the caller's UID appears in the room's `blockList` (blocked by an existing member) or if any room member is in the caller's blocked list; on successful join, merges the caller's blocked UIDs into `rooms/{roomId}.blockList`. Requires composite Firestore index on `(mode, status, isLocked, backgroundTheme, memberCount)` — deployed in `firestore.indexes.json`.
- **Output:** `{ roomId: string, isNewRoom: boolean }`

### `createCustomRoom`
`functions/src/matchmaking/createCustomRoom.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ backgroundTheme?: string }`
- **Process:** Generates 5-char crypto-random room ID. Creates `rooms/{roomId}` with `mode: group`, `roomType: custom`, `status: active`. `backgroundTheme` is always written (valid string when provided and valid, otherwise `null`). Adds creator to `rooms/{roomId}/members` in RTDB.
- **Output:** `{ roomId: string }`

### `joinRoomById`
`functions/src/matchmaking/joinRoomById.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ roomId: string }`
- **Process:** Validates room exists, is not expired/padding, not locked, not full. Before joining, fetches the caller's blocked list. Rejects the join if the caller's UID appears in the room's `blockList` (blocked by an existing member) or if any room member is in the caller's blocked list. On successful join, merges the caller's blocked UIDs into `rooms/{roomId}.blockList`. Adds caller to `rooms/{roomId}.users` and RTDB members. Returns room info.
- **Output:** `{ roomId: string, mode: string, roomType: string }`

### `leaveRoom`
`functions/src/matchmaking/leaveRoom.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ roomId: string }`
- **Process:** Removes caller from `rooms/{roomId}.users`, decrementing the leaver's entries in `rooms/{roomId}.blockList` and removing entries with `amount = 0`. If room empty, tombstones it (`status: padding`). Clears RTDB member, typing, and presence nodes. For 1v1 rooms: if one user remains after the caller leaves, transitions the room to a 30-second padding window and immediately re-queues the remaining user in `waiting_pool` with their original `interestVector` and the room's `backgroundTheme` preserved — ensuring theme partitioning survives a partner-left re-queue.
- **Output:** `{ success: true }`

### `setRoomLock`
`functions/src/matchmaking/setRoomLock.ts`
- **Trigger:** callable (authenticated)
- **Input:** `{ roomId: string, isLocked: boolean }`
- **Process:** Verifies caller is room participant. Sets `rooms/{roomId}.isLocked`.
- **Output:** `{ success: true }`

### `expireRooms`
`functions/src/matchmaking/expireRooms.ts`
- **Trigger:** scheduled — every 2 minutes
- **Process:** Three operations: (1) expire padding rooms past `paddingUntil`, (2) reset stale `matching_in_progress` docs, (3) heal ghost rooms (RTDB members but Firestore room missing). Re-checks RTDB membership before expiring (crash-safe).
- **Output:** void (cron)

### `cleanupMember`
`functions/src/matchmaking/cleanupMember.ts`
- **Trigger:** RTDB `onValueDeleted` — `rooms/{roomId}/members/{uid}` — **region: `asia-southeast1`**
- **Process:** When a member's RTDB presence node is deleted (network-drop disconnect), runs server-side room cleanup. If room is now empty, tombstones the Firestore room (`status: padding`). For 1v1 rooms with one user remaining: re-queues them in `waiting_pool` with their original `interestVector` and the room's `backgroundTheme` preserved, then removes their RTDB membership so a second invocation can decrement `memberCount` to 0 and let `expireRooms` tombstone the room. Mirrors the re-queue behaviour of `leaveRoom` for the disconnect (unclean exit) path.
- **Output:** void (trigger)

### `cleanupPoolMember`
`functions/src/matchmaking/cleanupPoolMember.ts`
- **Trigger:** RTDB `onValueDeleted` — `pool_presence/{uid}` — **region: `asia-southeast1`**
- **Process:** When pool presence deleted (disconnect), removes user from `waiting_pool/{uid}`.
- **Output:** void (trigger)

---

## Friends (2 functions)

### `onFriendshipCreated`
`functions/src/friends/createFriendship.ts`
- **Trigger:** Firestore `onDocumentCreated` — `friendships/{friendshipId}`
- **Process:** When a `friendships` doc is created, writes `friends/{uid1}/{uid2} = true` and `friends/{uid2}/{uid1} = true` in RTDB using admin credentials. Admin credentials are required because the client-side RTDB rule is owner-only (`auth.uid == $ownerUid`), which would deny writing the peer's node. These nodes gate the `user_status` read rule that allows friends to see each other's presence.
- **Output:** void (trigger)

### `onFriendshipDeleted`
`functions/src/friends/removeFriendship.ts`
- **Trigger:** Firestore `onDocumentDeleted` — `friendships/{friendshipId}`
- **Process:** When a `friendships` doc is deleted, deletes the entire `friend_messages/{friendshipId}/messages` subcollection to prevent orphaned data consuming storage indefinitely. Also removes both RTDB `friends/{uid1}/{uid2}` and `friends/{uid2}/{uid1}` nodes so the `user_status` read rule reverts to owner-only.
- **Output:** void (trigger)

---

## Utility (1 function)

### `helloWorld`
`functions/src/index.ts`
- **Trigger:** callable (authenticated), public CORS
- **Input:** `{ message: string }`
- **Process:** Echoes the message back. Validates non-empty string. Used by `hello` feature for CF smoke testing.
- **Output:** `{ message: string }`

---

## Dead Code

- `functions/src/chat/onProtoPresenceDeleted.ts` — disabled stub (`export {}`). RTDB trigger for proto-session presence cleanup. Re-enable after full matchmaking integration.

---

## Shared Utilities

`functions/src/matchmaking/_utils.ts`
- `generateRoomId()` — 5-char crypto-random ID from `[A-Z0-9a-z]`
- `generateKey()` — `crypto.randomBytes(32)` hex string for AES-256
- `cosineSimilarity(a, b)` — dot product / magnitudes; returns 0 for zero vectors
- `RoomData` interface — Firestore room document shape

---

## Operational Scripts

### `tools/setup-firestore-ttl.sh`
One-time idempotent script that applies the Firestore TTL policy for `chat_rooms/{id}/messages.expiresAt`.

`sendMessage` sets `expiresAt = now + 3 days` on every message. Without the TTL policy in place, messages from crashed or abandoned sessions (where `endSession` never fired) persist in Firestore indefinitely — violating the privacy guarantee.

**Must be run once per Firebase project.** Safe to re-run (gcloud is idempotent for TTL field definitions).

```bash
# Prerequisites: gcloud authenticated, project set to cozytalk-5d984
gcloud auth login
gcloud config set project cozytalk-5d984

bash tools/setup-firestore-ttl.sh
```

**Verify:** Firebase Console → Firestore → Data → TTL policies. Look for collection group `messages`, field `expiresAt`. Propagation to existing documents can take up to 24 hours after first deployment.
