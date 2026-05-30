# Feature: matchmaking

1v1 pool matching and group room joining. All matching logic runs in Cloud Functions — never on client.

## File Map

```
features/matchmaking/
├── domain/
│   ├── entities/
│   │   ├── matchmaking_status.dart    MatchmakingStatus enum
│   │   └── room.dart                  Room (roomId, roomType, mode, status, ...)
│   ├── repositories/matchmaking_repository.dart  abstract MatchmakingRepository
│   └── usecases/
│       ├── cancel_1v1_pool.dart       Cancel1v1Pool
│       ├── create_custom_room.dart    CreateCustomRoom
│       ├── join_1v1_pool.dart         Join1v1Pool
│       ├── join_group_room.dart       JoinGroupRoom
│       ├── join_room_by_id.dart       JoinRoomById
│       ├── leave_room.dart            LeaveRoom
│       ├── set_room_lock.dart         SetRoomLock
│       ├── watch_1v1_match.dart       Watch1v1Match
│       └── watch_room.dart            WatchRoom
├── data/
│   ├── datasources/matchmaking_datasource.dart        MatchmakingDatasourceImpl
│   ├── models/room_model.dart                         @freezed RoomModel + toEntity()
│   └── repositories/matchmaking_repository_impl.dart
└── presentation/
    ├── providers/matchmaking_provider.dart            matchmakingNotifierProvider, MatchmakingNotifier, MatchmakingState
    └── screens/matchmaking_test_screen.dart           MatchmakingTestScreen (dev/test only)
```

## Providers

| Provider | Type | Description |
|---|---|---|
| `matchmakingNotifierProvider` | `NotifierProvider<MatchmakingNotifier, MatchmakingState>` | room lifecycle |

## State

`MatchmakingStatus` enum: `idle | searching | waiting1v1 | matched | creating | error`

`MatchmakingState` — `status`, `currentRoom` (Room?), `roomId` (String?), `isNewRoom` (bool), `interestText` (String), `backgroundTheme` (String?), `error` (String?)

`Room` entity fields: `roomId` (String), `roomType` (RoomType: public|custom), `mode` (RoomMode: oneToOne|group), `status` (RoomStatus: active|padding|expired)

## Room Types

| Dimension | Values | Meaning |
|---|---|---|
| `mode` | `1v1` / `group` | 2 users vs 2–5 users |
| `roomType` | `public` / `custom` | pool-matched vs created with custom ID |

## Key Behavior

- 1v1 flow: `join1v1Pool` (CF) → `match1v1Users` Firestore trigger fires → `watch1v1Match` stream picks up result
- Group flow: `joinGroupRoom` (CF) — 3-phase: find candidate rooms → compute cosine similarity → join or create
- Custom room: `createCustomRoom` (CF) → share 5-char room ID → partner uses `joinRoomById` (CF)
- `cancel1v1Pool` returns `{success: false, reason: "matching_in_progress"}` if already matching — Flutter must handle this case
- Interest vectors: Vertex AI `text-multilingual-embedding-002`, 256 dims, cosine threshold 0.65
- Stored in `waiting_pool/{uid}.interestVector` (256-element array); text cached in `SharedPreferences`
- `match1v1Users` CF deployed to `asia-southeast1` (co-located with RTDB — intentional for RTDB write latency)
- **Background theme:** optional room theme selector (`kao_tapu`, `red_lotus_lake`, `sea_of_cloud`, `lumphini_park`). Stored in `MatchmakingState.backgroundTheme`; forwarded to `join1v1Pool`, `joinGroupRoom`, and `createCustomRoom` CFs. Matching rule: themed users match same-theme or unthemed candidates (unthemed = flexible, adopts the room's theme). The only blocked pairing is two users with different non-null themes. Unthemed users match anyone. `setBackgroundTheme(String?)` on the notifier; preserved across room transitions by `_idleState()`. Server validates against the four allowed IDs — invalid values are silently dropped to `null`. `backgroundTheme` is always written on rooms (valid string or `null`). `leaveRoom` CF preserves the room's `backgroundTheme` when re-queuing the remaining 1v1 user after their partner disconnects.

## Production Screens

- `screens/finding_room_screen.dart` — `FindingRoomScreen` ✅ integrated — see `docs/frontend/screens.md` for full wiring detail
- `screens/choose_room_type_screen.dart` — `ChooseRoomTypeScreen` ✅ integrated — back button uses `popUntil(isFirst)`
- `screens/join_room_id_screen.dart` — `JoinRoomIdScreen` ⬜ pending
- `screens/group_chat_screen.dart` — `GroupChatScreen` ⚠️ partial — `ConsumerStatefulWidget` but uses `shared/` providers only, not wired to `chatNotifierProvider`

## Notes

- `ref impl #3` — third canonical CA example
- All race conditions handled server-side (Firestore transactions in CFs)
- Client must never call matchmaking Firestore APIs directly — always through CF callable
