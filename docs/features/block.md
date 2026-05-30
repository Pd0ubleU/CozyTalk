# Block Feature

User-level blocking. A user can block up to 5 other users. Blocked relationships are enforced during room joining and 1v1 matching.

## Domain

| Class | File |
|---|---|
| `BlockedUser` | `domain/entities/blocked_user.dart` |
| `BlockRepository` | `domain/repositories/block_repository.dart` |
| `WatchBlockedUsers` | `domain/usecases/watch_blocked_users.dart` |
| `BlockUser` | `domain/usecases/block_user.dart` |
| `UnblockUser` | `domain/usecases/unblock_user.dart` |

## Data

| Class | File |
|---|---|
| `BlockedUserModel` | `data/models/blocked_user_model.dart` — `@freezed` DTO with `TimestampConverter` |
| `BlockDatasourceImpl` | `data/datasources/block_datasource.dart` — streams Firestore subcollection; calls `blockUser`/`unblockUser` CFs |
| `BlockRepositoryImpl` | `data/repositories/block_repository_impl.dart` |

## Presentation

| Class | File |
|---|---|
| `BlockState` | `presentation/providers/block_provider.dart` — fields: `status`, `blockedUsers`, `isSubmitting`, `error` |
| `BlockNotifier` | `presentation/providers/block_provider.dart` — subscribes in `build()` via `authNotifierProvider`; `block()` + `unblock()` actions |
| `blockNotifierProvider` | `presentation/providers/block_provider.dart` |

## Firestore

Collection: `users/{uid}/blocked/{blockedUid}`

| Field | Type |
|---|---|
| `blockedUid` | string |
| `displayName` | string? |
| `blockedAt` | Timestamp |

Max 5 entries per user.

## Room Block Enforcement

`rooms/{roomId}.blockList`: `Array<{ blockedBy, userId, amount }>`

- `joinGroupRoom` / `joinRoomById`: checks blocklist before join; merges on success
- `leaveRoom`: decrements entries on leave
- `match1v1Users`: skips mutually-blocked pairs

## Admin

`adminGetBlockedUsers` CF lets admins view a user's block list. Surfaced via `AdminUsersNotifier.loadBlockedUsers(uid)` in the admin console Users tab.
