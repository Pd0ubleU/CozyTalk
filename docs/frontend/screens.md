# Production Screens

All screens in `apps/mobile/lib/screens/`. These are the production frontend — wired to CA `features/` via Riverpod providers.

## Main Screens

| Class | File | Route | Extends | Integration |
|---|---|---|---|---|
| `HomeScreen` | `screens/home_screen.dart` | `/` | ConsumerStatefulWidget | ✅ integrated — notification badge wired to `friendsNotifierProvider.incomingRequests`; shows `OfflineChip` when offline; avatar write errors (mood/dress) surface as SnackBar via `ref.listen` on `avatarDecorationNotifierProvider` |
| `ChatScreen` | `screens/chat_screen.dart` | `/chat` | ConsumerStatefulWidget | ✅ integrated — wired to `chatNotifierProvider`; GIF via Giphy API |
| `GroupChatScreen` | `screens/group_chat_screen.dart` | `/group-chat` | ConsumerStatefulWidget | ✅ integrated — wired to `chatNotifierProvider` + `matchmakingNotifierProvider` (isLocked); GIF via Giphy API |
| `FindingRoomScreen` | `screens/finding_room_screen.dart` | `/finding-room` | ConsumerStatefulWidget | ✅ integrated — calls `join1v1Pool()` / `joinGroupRoom()` / `createCustomRoom()` / `joinRoomById(roomId)` based on `roomType` arg; navigates to `chatScreen` (1v1) or `groupChatScreen` (group/create/joinById) on `matched`; sets room lock for `create` type; `cancelSearch()` on Cancel or dispose; shows `OfflineCard` instead of tuk-tuk animation when offline; `_startMatchmaking` checks `isConnected` and returns early if offline; `cancelSearch` in `dispose` deferred via `Future.microtask` (prevents Riverpod provider-modified-during-build crash) |
| `ChooseRoomTypeScreen` | `screens/choose_room_type_screen.dart` | `/choose-room-type` | StatefulWidget | ✅ integrated — back button uses `popUntil(isFirst)` to return home |
| `JoinRoomIdScreen` | `screens/join_room_id_screen.dart` | `/join-room` | StatefulWidget | ✅ integrated — passes `roomType: 'joinById'` + `roomId` to FindingRoomScreen |
| `ProfileScreen` | `screens/profile_screen.dart` | `/profile` | ConsumerStatefulWidget | ✅ integrated — wired to `profileNotifierProvider` + `authNotifierProvider` + `avatarProvider`; shows `OfflineChip` when offline |
| `ProfileEditScreen` | `screens/profile_edit_screen.dart` | `/profile/edit` | ConsumerStatefulWidget | ✅ integrated — pre-fills from `profileNotifierProvider`, saves via `updateDisplayName`/`updateInterest`, error via snackbar, success via `showInfoDialog`, navigated directly from `ProfileScreen`; shows `OfflineChip`; Save button grayed and blocked when offline; SnackBar shown on offline tap without calling notifier |
| `DressUpScreen` | `screens/dress_up_screen.dart` | `/dressup` | ConsumerStatefulWidget | ✅ integrated — pre-fills selected accessory from `avatarDecorationNotifierProvider.decoration.hatKey`; Save calls `updateHat(uid, selectedKey)` via `avatarDecorationNotifierProvider`; uid from `authNotifierProvider`; save guard blocks re-entry while saving; error surfaces as SnackBar via `ref.listen` |
| `MoodScreen` | `screens/mood_screen.dart` | `/mood` | ConsumerStatefulWidget | ✅ integrated — `initState` reads `moodKey` from `avatarDecorationNotifierProvider`; Save calls `updateMood(uid, selectedKey)` via CA notifier; uid from `authNotifierProvider`; save guard on `status == saving`; errors surface as floating SnackBar via `ref.listen` |
| `FriendsScreen` | `screens/friends_screen.dart` | `/friends` | ConsumerStatefulWidget | ✅ integrated — `friendsNotifierProvider.friends` replaces mock data; `removeFriend(friendshipId)` wired through notifier; errors surface as SnackBar via `ref.listen`; local-only state (note, block, unread) keyed by `friendshipId`; shows `OfflineCard` when offline |
| `FriendChatScreen` | `screens/friend_chat_screen.dart` | `/friends/chat` | StatefulWidget | ⬜ pending |
| `BlockedScreen` | `screens/blocked_screen.dart` | `/blocked` | ConsumerStatefulWidget | ✅ integrated |
| `NotificationScreen` | `screens/notification_screen.dart` | `/notification` | ConsumerStatefulWidget | ✅ integrated — `friendsNotifierProvider.incomingRequests`; accept/decline wired; App Update static card |
| `SelectBackgroundScreen` | `screens/select_background_screen.dart` | `/select-background` | ConsumerStatefulWidget | ✅ integrated — wired to `matchmakingNotifierProvider`; calls `setBackgroundTheme(id)` before navigating so the selected theme drives CF-side matchmaking filtering; passes `{ roomType, roomName, bgImage, isGroup }` to `findingRoom` route; back button pops to `chooseRoomType` |
| `LoginScreen` | `screens/login_screen.dart` | — | ConsumerStatefulWidget | ✅ integrated — used as `ui.LoginScreen` in `_MainUIAuthRouter` (`_useMainUI = true`); wired to `authNotifierProvider`; shows `OfflineChip` + blocks all sign-in actions when offline; `@cozytalk.com` logins redirect to `AdminConsoleScreen` |
| `SignupScreen` | `screens/signup_screen.dart` | — | ConsumerStatefulWidget | ✅ integrated — pushed from `LoginScreen`; `@cozytalk.com` emails blocked at form validation |

## Admin Screens (admin role only)

All admin screens are wired to `features/admin/` via `adminReportsProvider`, `adminUsersProvider`, and `adminDashboardProvider`. Display models in `admin_shared.dart` remain unchanged — the console screen maps domain entities to them at build time.

| Class | File | Integration | Notes |
|---|---|---|---|
| `AdminConsoleScreen` | `screens/admin_console_screen.dart` | ✅ integrated | `ConsumerStatefulWidget`; watches 3 providers; maps domain → display models; handles ban/unban/resolve; report count per user computed from loaded `reportsState.reports` (no extra Firestore queries) |
| `AdminProfileScreen` | `screens/admin_profile_screen.dart` | ✅ integrated | `ConsumerStatefulWidget`; reads `authNotifierProvider` for real email/name; username derived from email prefix (`superadmin@cozytalk.com` → `superadmin`), falls back to `displayName` then `'Admin'`; logout calls `signOut()` |
| `AdminReportDetailScreen` | `screens/admin_report_detail_screen.dart` | ✅ integrated | Pure display + callbacks; `onGetChatLog: Future<String?> Function()?` — when set, shows "View session transcript" button that fetches JSON via signed URL and displays `_ChatTranscriptSheet`; evidence images load via `Image.network` with fullscreen tap via `InteractiveViewer` |
| `AdminBanDetailScreen` | `screens/admin_ban_detail_screen.dart` | ✅ no change needed | Pure display + callback; callbacks wired by `AdminConsoleScreen` |
| `AdminUsersTab` | `screens/admin_users_tab.dart` | ✅ no change needed | Receives live `users` list from console |
| `AdminReportsTab` | `screens/admin_reports_tab.dart` | ✅ no change needed | Receives live `reports` list from console |
| `AdminBannedTab` | `screens/admin_banned_tab.dart` | ✅ no change needed | Receives live `banned` list from console |

## Dialogs / Shared

| Class | File | Notes |
|---|---|---|
| `ThoughtBubbleDialog` | `screens/thought_bubble_dialog.dart` | |
| `FriendProfileDialog` | `screens/friend_profile_dialog.dart` | private class |
| `RemoveFriendDialog` | `screens/remove_friend_dialog.dart` | private class |
| block dialogs | `screens/block_dialogs.dart` | |
| shared widgets | `screens/widgets.dart` | |
| admin shared | `screens/admin_shared.dart` | |

## App Routes

Defined in `apps/mobile/lib/theme/app_routes.dart` as `AppRoutes` constants.
Registered in `main.dart` under `MaterialApp.routes` (production mode only, `_useMainUI = true`).

## Dev Mode Screens (features/ path)

When `_useMainUI = false`, the app uses `_AuthRouter` → `features/auth/presentation/screens/login_screen.dart` → `features/hello/presentation/screens/hello_screen.dart`.

## Shared Widgets (`screens/widgets.dart`)

| Widget | Notes |
|---|---|
| `buildAppBar(context, title)` | Standard back-arrow AppBar. `IconButton` has `tooltip: 'Go back'` for WCAG 2.2 AA. |
| `PillButton` | Small pill-shaped action button (Accept / Decline / Unblock). Text child = accessible label. |
| `AvatarActionButton` | SVG icon button for Undo/Redo/Delete in MoodScreen + DressUpScreen. Requires `semanticLabel` param. Wraps in `Semantics(label: ..., button: true, enabled: ...)`. |
| `UserAvatarWidget` | Decorative avatar image — wrapped in `ExcludeSemantics`. |

## Accessibility (WCAG 2.2 AA — Criterion 4.1.2)

All production screens have semantic labels on interactive elements:
- Icon-only `GestureDetector`s wrapped in `Semantics(label: '...', button: true, child: ...)`
- `IconButton`s without visible text have `tooltip: '...'`
- Decorative images wrapped in `ExcludeSemantics`
- Barrier/overlay-dismiss `GestureDetector`s wrapped in `ExcludeSemantics`

Each screen test file (`test/screens/`) has a `group('accessibility', ...)` block verifying labels via `find.bySemanticsLabel` / `find.byTooltip`.

## Admin Routing (`_useMainUI = true`)

`_MainUIAuthRouter` checks the authenticated user's email after sign-in:
- `email.endsWith('@cozytalk.com')` → `AdminConsoleScreen`
- all other emails → `HomeScreen`

`SignupScreen` blocks `@cozytalk.com` email addresses at form validation to prevent regular users from creating admin accounts.

## Integration Rules (summary)

Convert `StatefulWidget` → `ConsumerStatefulWidget`. Wire `ref.watch/read`. Never change widget tree or visual design. One screen per PR. See CLAUDE.md §9.
