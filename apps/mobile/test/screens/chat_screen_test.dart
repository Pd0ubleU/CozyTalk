import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart'
    as chat_entity;
import 'package:mobile/features/chat/domain/entities/session_status.dart';
import 'package:mobile/features/chat/presentation/providers/chat_provider.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/screens/chat_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';
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
  MatchmakingState _initial;

  _FakeMatchmakingNotifier({
    MatchmakingState initial = const MatchmakingState(),
  }) : _initial = initial;

  @override
  MatchmakingState build() => _initial;

  void setStateForTest(MatchmakingState s) {
    _initial = s;
    state = s;
  }

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
  Future<void> setRoomLock({required bool isLocked}) async {}

  @override
  Future<void> leaveRoom() async {}

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

// ── Helpers ───────────────────────────────────────────────────────────────────

const _kArgs = {
  'roomId': 'TEST1',
  'roomName': 'Test Room',
  'bgImage': 'assets/images/backgrounds/red_lotus_lake.png',
  'roomType': '1v1',
};

/// Pumps one frame to execute [addPostFrameCallback], then advances 400 ms to
/// drain the non-cancellable [Future.delayed(350ms)] created inside
/// [_scrollToBottom]. Without this the test framework reports a pending timer.
Future<void> _pump(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

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
            settings: RouteSettings(name: '/', arguments: _kArgs),
            builder: (_) => const ChatScreen(),
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
  group('ChatScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
      await _pump(tester);
      expect(find.byType(ChatScreen), findsOneWidget);
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
      expect(find.text('Test Room'), findsOneWidget);
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

    testWidgets('clearing text field calls setTyping false', (tester) async {
      final chatFake = _FakeChatNotifier();
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

      await tester.enterText(find.byType(TextField).first, 'hello');
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pump();

      expect(chatFake.lastTypingValue, false);
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

    testWidgets('empty text does not call sendMessage', (tester) async {
      final chatFake = _FakeChatNotifier();
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

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

    testWidgets('partner leaving triggers forceDisconnect', (tester) async {
      final chatFake = _FakeChatNotifier(
        initial: const ChatState(
          status: SessionStatus.chatting,
          sessionId: 's1',
        ),
      );
      final matchFake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(status: MatchmakingStatus.matched),
      );
      await tester.pumpWidget(_buildScreen(chatFake, matchFake: matchFake));
      await _pump(tester);

      matchFake.setStateForTest(const MatchmakingState());
      await tester.pump();

      expect(chatFake.forceDisconnectCount, 1);
    });

    testWidgets("gif_other message renders left-aligned, not right", (
      tester,
    ) async {
      final chatFake = _FakeChatNotifier(
        initial: ChatState(
          currentUserId: 'u1',
          messages: [
            chat_entity.ChatMessage(
              id: 'msg1',
              senderId: 'other_user',
              displayName: 'Brave Bear',
              text: 'https://media.giphy.com/test.gif',
              timestamp: DateTime(2025),
            ),
          ],
        ),
      );
      await tester.pumpWidget(_buildScreen(chatFake));
      await _pump(tester);

      // A gif from another user must not produce an end-aligned row (which
      // would place the bubble on the "me" / right side).
      expect(
        find.byWidgetPredicate(
          (w) => w is Row && w.mainAxisAlignment == MainAxisAlignment.end,
        ),
        findsNothing,
      );
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildScreen(_FakeChatNotifier()));
          await _pump(tester);
          expect(find.bySemanticsLabel('Send message'), findsOneWidget);
          expect(find.bySemanticsLabel('End chat'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
