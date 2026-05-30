# Friends Feature

Prototype implementation. `FriendsScreen` (`screens/friends_screen.dart`) is integrated with `friendsNotifierProvider`.

---

## Overview

Allows users to send friend requests, accept or decline them, chat permanently with accepted friends, and see real-time presence and room status for each friend.

---

## Firestore Collections

| Collection | Purpose |
|---|---|
| `friend_requests/{id}` | Pending / resolved friend requests |
| `friendships/{id}` | One doc per accepted pair; ID = sorted UIDs joined with `_` |
| `friend_messages/{id}/messages/{id}` | Permanent chat messages between friends |

See `docs/database/schema.md` for full field lists and security rules.

---

## RTDB Paths

| Path | Purpose |
|---|---|
| `user_status/{uid}` | Read by friends via `friends/{uid}/{auth.uid} === true` rule (see schema.md) |
| `friends/{ownerUid}/{friendUid}` | Denormalized friendship flag (`true`) — used only for RTDB rule evaluation |

---

## Domain Layer

**Entities** (`domain/entities/`)

| Entity | Key fields |
|---|---|
| `AppUser` | `uid`, `displayName` — lightweight view of any user for search |
| `Friend` | `friendshipId`, `friendUid`, `friendDisplayName`, `chatRoomId`, `friendedAt` |
| `FriendRequest` | `id`, `fromUid`, `fromDisplayName`, `toUid`, `status` (enum), `createdAt` |
| `FriendMessage` | `id`, `senderId`, `senderDisplayName`, `text`, `timestamp` |
| `FriendRoomStatus` | `roomId`, `memberCount`, `maxUsers`, `isLocked`, `mode` — snapshot of a friend's current room |

**Use cases** (`domain/usecases/`)

`WatchAllUsers` · `WatchFriends` · `WatchIncomingRequests` · `WatchFriendMessages` · `SendFriendRequest` · `AcceptFriendRequest` · `DeclineFriendRequest` · `RemoveFriend` · `SendFriendMessage` · `WatchFriendPresence` · `WatchFriendLastMessage` · `WatchFriendRoom`

---

## Data Layer

**Models** — `@freezed` DTOs with `toEntity()` extensions. Firestore `Timestamp` fields are normalised to `int` milliseconds before `fromJson`.

**`FriendsDatasourceImpl`** — direct Firestore and RTDB reads/writes (no Cloud Function). Constructor takes `FirebaseFirestore`, `FirebaseAuth`, and `FirebaseDatabase`.

- `acceptFriendRequest`: Firestore batch (update request + create friendship doc), then writes `friends/{currentUid}/{fromUid}: true` and `friends/{fromUid}/{currentUid}: true` to RTDB.
- `watchFriendPresence(friendUid)`: streams `user_status/{friendUid}` existence as `bool`.
- `watchFriendLastMessage(chatRoomId)`: streams the latest message text from `friend_messages/{chatRoomId}/messages` (descending by timestamp, limit 1).
- `watchFriendRoom(friendUid)`: streams `user_status/{friendUid}`; when `status == 'in_room'`, does a one-time Firestore `rooms/{roomId}` fetch and emits `FriendRoomStatus`; emits `null` otherwise.

**Friendship ID** — deterministic: `[uid1, uid2]..sort()` joined with `_`. Used as both the `friendships` document ID and the `friend_messages` sub-collection path.

---

## Presentation Layer

### State — `FriendsState`

| Field | Type | Purpose |
|---|---|---|
| `friends` | `List<Friend>` | Active friendships |
| `incomingRequests` | `List<FriendRequest>` | Pending requests for the current user |
| `allUsers` | `List<AppUser>` | All users (for friend search in dev screens) |
| `isLoading` | `bool` | Mutation in progress |
| `error` | `String?` | Last error message; cleared by `clearError()` |
| `presenceMap` | `Map<String, bool>` | keyed by `friendUid` — `true` when `user_status` node exists |
| `lastMessageMap` | `Map<String, String>` | keyed by `chatRoomId` — last message text |
| `roomMap` | `Map<String, FriendRoomStatus?>` | keyed by `friendUid` — current room or `null` |

Per-friend enrichment subscriptions are managed by `_updateEnrichmentSubscriptions()` in `FriendsNotifier`, called whenever the `friends` list changes. Stale subscriptions are cancelled when a friend is removed.

### Providers

| Provider | Type | Purpose |
|---|---|---|
| `friendsDatasourceProvider` | `Provider<FriendsDatasource>` | Shared datasource instance |
| `friendsRepositoryProvider` | `Provider<FriendsRepository>` | Shared repository instance |
| `friendsNotifierProvider` | `NotifierProvider<FriendsNotifier, FriendsState>` | Friends list + requests + enrichment maps |
| `friendChatNotifierProvider` | `NotifierProvider<FriendChatNotifier, FriendChatState>` | Single active chat; `enterChat(roomId, name)` starts subscription |

### Production Screen

`FriendsScreen` (`screens/friends_screen.dart`) — integrated with `friendsNotifierProvider`. Maps `domain.Friend` → screen `Friend` model via `_toScreenFriend(f, state)`, pulling `isOnline` from `presenceMap`, `lastMessage` from `lastMessageMap`, and `room` (as `RoomInfo`) from `roomMap`. Notes, block state, and unread counts remain local-only state for this prototype.

### Prototype Screens (dev only)

| Screen | Purpose |
|---|---|
| `FriendsTestScreen` | Dev hub: current user info, all-users list with "Add" buttons, navigation to friends list |
| `FriendsListScreen` | Tabbed view: "Friends" tab (tap to chat, long-press to remove) + "Requests" tab (accept/decline) |
| `FriendDirectChatScreen` | Real-time permanent chat with a specific friend |

Entry point: **HelloScreen → "Test Friends" button**.

---

## Key Design Decisions

- **Plaintext messages** — friend chat stores messages without encryption (prototype only).
- **Permanent history** — no `expiresAt` TTL; messages persist indefinitely.
- **Client-side writes** — no Cloud Function for friendship creation; the batch write atomically updates the request and creates the friendship doc.
- **`users` read broadened** — `firestore.rules` `users/{uid}` read changed from `isOwner` to `isSignedIn` to allow the friends user-search query.
- **RTDB friend-only presence rule** — `user_status/{uid}` is readable by friends, not the public. The `friends/{ownerUid}/{friendUid}: true` RTDB node is the rule anchor; it is client-written on `acceptFriendRequest` and cleaned up server-side by the `onFriendshipDeleted` CF.
- **N+1 enrichment subscriptions** — each friend has separate RTDB and Firestore listeners; acceptable for this prototype's small friend lists.
