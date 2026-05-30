import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/screens/group_chat_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';
import 'package:mobile/shared/press_bounce_btn.dart';
import 'package:mobile/shared/user_profile.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithGoogle() async {}
}

class _FakeChatNotifier extends ChatNotifier {
  final ChatState _initial;
  final List<String> sentMessages = [];
  int setTypingCount = 0;
  bool? lastTypingValue;
  int forceDisconnectCount = 0;

  _FakeChatNotifier({ChatState initial = const ChatState()})
    : _initial = initial;

  @override
  ChatState build() => _initial;

  @override
  void enterSession({
    required String sessionId,
    required String currentUserId,
    String? currentUserDisplayName,
    String? currentUserPhotoUrl,
  }) {}

  @override
  Future<void> sendMessage(String text) async => sentMessages.add(text);

  @override
  Future<void> setTyping(bool isTyping) async {
    setTypingCount++;
    lastTypingValue = isTyping;
  }

  @override
  Future<void> endSession() async {}

  @override
  void forceDisconnect() => forceDisconnectCount++;
}

class _FakeMatchmakingNotifier extends MatchmakingNotifier {
  final MatchmakingState _initial;
  bool? lastLockValue;
  int leaveRoomCount = 0;

  _FakeMatchmakingNotifier({
    MatchmakingState initial = const MatchmakingState(),
  }) : _initial = initial;

  @override
  MatchmakingState build() => _initial;

  @override
  Future<void> join1v1Pool() async {}

  @override
  Future<void> joinGroupRoom() async {}

  @override
  Future<void> createCustomRoom() async {}

  @override
  Future<void> joinRoomById(String roomId) async {}

  @override
  Future<void> cancelSearch() async {}

  @override
  Future<void> setRoomLock({required bool isLocked}) async =>
      lastLockValue = isLocked;

  @override
  Future<void> leaveRoom() async => leaveRoomCount++;

  @override
  void setInterestText(String text) {}

  @override
  Future<void> loadSavedInterestText() async {}
}

class _FakeAvatarNotifier extends AvatarNotifier {
  @override
  AvatarState build() => AvatarState();
}

class _FakeUserProfileNotifier extends UserProfileNotifier {
  @override
  UserProfileState build() => const UserProfileState();
}

/// Pumps one frame to execute [addPostFrameCallback], then advances 400 ms to
/// drain the non-cancellable [Future.delayed(350ms)] inside [_scrollToBottom].
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

// ── Helper ────────────────────────────────────────────────────────────────────

const _kArgs = {
  'roomId': 'GRP01',
  'roomName': 'Test Group',
  'bgImage': 'assets/images/backgrounds/kao_tapu.png',
  'roomType': 'group',
  'maxMembers': 5,
};

Widget _buildScreen(
  _FakeChatNotifier chatFake, {
  _FakeMatchmakingNotifier? matchFake,
  AuthState auth = const AuthState(
    status: AuthStatus.authenticated,
    user: AuthUser(uid: 'u1'),
  ),
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(initial: auth)),
      chatNotifierProvider.overrideWith(() => chatFake),
      matchmakingNotifierProvider.overrideWith(
        () => matchFake ?? _FakeMatchmakingNotifier(),
      ),
      avatarProvider.overrideWith(() => _FakeAvatarNotifier()),
      userProfileProvider.overrideWith(() => _FakeUserProfileNotifier()),
    ],
    child: MaterialApp(
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(
            settings: const RouteSettings(name: '/', arguments: _kArgs),
            builder: (_) => const GroupChatScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (_) => const Scaffold(body: Text('home')),
        );
      },
      initialRoute: '/',
    ),
  );
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('GroupChatScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.byType(GroupChatScreen), findsOneWidget);
    });

    testWidgets('shows Keep it friendly warning text', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.textContaining('Keep it friendly'), findsOneWidget);
    });

    testWidgets('shows Type here hint in text field', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.text('Type here ...'), findsOneWidget);
    });

    testWidgets('shows room name from route args', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.text('Test Group'), findsOneWidget);
    });

    testWidgets('shows lock toggle in header', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(
        find.byIcon(Icons.lock_open_rounded).evaluate().isNotEmpty ||
            find.byIcon(Icons.lock_rounded).evaluate().isNotEmpty,
        isTrue,
      );
    });

    testWidgets('lock shows locked state when currentRoom.isLocked is true', (
      tester,
    ) async {
      final room = Room(
        roomId: 'GRP01',
        roomType: RoomType.custom,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 1,
        users: const ['u1'],
        isLocked: true,
        createdAt: DateTime(2025),
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'GRP01',
          currentRoom: room,
        ),
      );
      await tester.pumpWidget(
        _buildScreen(_FakeChatNotifier(), matchFake: matchFake),
      );
      await _pump(tester);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('tapping lock toggle calls setRoomLock', (tester) async {
      final room = Room(
        roomId: 'GRP01',
        roomType: RoomType.custom,
        mode: RoomMode.group,
        status: RoomStatus.active,
        maxUsers: 5,
        memberCount: 1,
        users: const ['u1'],
        isLocked: false,
        createdAt: DateTime(2025),
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'GRP01',
          currentRoom: room,
        ),
      );
      await tester.pumpWidget(
        _buildScreen(_FakeChatNotifier(), matchFake: matchFake),
      );
      await _pump(tester);

      await tester.tap(find.byIcon(Icons.lock_open_rounded));
      await tester.pump();

      expect(matchFake.lastLockValue, true);
    });

    testWidgets('typing in text field calls setTyping', (tester) async {
      final chatFake = _FakeChatNotifier();
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.pump();

      expect(chatFake.setTypingCount, greaterThanOrEqualTo(1));
      expect(chatFake.lastTypingValue, true);
    });

    testWidgets('isSending=true prevents sendMessage when send tapped', (
      tester,
    ) async {
      final chatFake = _FakeChatNotifier(
        initial: const ChatState(isSending: true),
      );
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.pump();

      final sendBtn = find.ancestor(
        of: find.byWidgetPredicate(
          (w) =>
              w is Container &&
              (w.decoration as BoxDecoration?)?.color ==
                  const Color(0xFFEAC163),
        ),
        matching: find.byType(GestureDetector),
      );
      if (sendBtn.evaluate().isNotEmpty) {
        await tester.tap(sendBtn.first, warnIfMissed: false);
        await tester.pump();
      }

      expect(chatFake.sentMessages, isEmpty);
    });

    testWidgets(
      'tapping Leave header button calls leaveRoom and forceDisconnect',
      (tester) async {
        final chatFake = _FakeChatNotifier();
        final matchFake = _FakeMatchmakingNotifier();
        await tester.pumpWidget(_buildScreen(chatFake, matchFake: matchFake));
        await _pump(tester);

        // First PressBounceBtn in the header is the back/leave button
        await tester.tap(find.byType(PressBounceBtn).first);
        await tester.pump();

        // LeaveRoomDialog is now visible — tap the Leave confirmation
        await tester.tap(find.text('Leave'));
        await tester.pump();

        expect(matchFake.leaveRoomCount, 1);
        expect(chatFake.forceDisconnectCount, 1);
      },
    );

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
          await _pump(tester);
          expect(find.bySemanticsLabel('Send message'), findsOneWidget);
          expect(find.bySemanticsLabel('End chat'), findsOneWidget);
          expect(find.bySemanticsLabel('Toggle room lock'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
