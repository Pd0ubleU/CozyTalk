import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/chat/domain/entities/chat_message.dart';
import 'package:mobile/features/chat/domain/entities/session_status.dart';
import 'package:mobile/features/chat/domain/entities/typing_user.dart';
import 'package:mobile/features/chat/presentation/providers/chat_provider.dart';

class _TestChatNotifier extends ChatNotifier {
  final ChatState _initial;
  _TestChatNotifier({required ChatState initial}) : _initial = initial;

  @override
  ChatState build() => _initial;
}

void main() {
  group('ChatNotifier', () {
    test(
      'forceDisconnect transitions chatting to disconnected and clears session',
      () {
        final container = ProviderContainer(
          overrides: [
            chatNotifierProvider.overrideWith(
              () => _TestChatNotifier(
                initial: ChatState(
                  status: SessionStatus.chatting,
                  sessionId: 's1',
                  currentUserId: 'u1',
                  messages: [
                    ChatMessage(
                      id: 'm1',
                      senderId: 'u1',
                      displayName: 'Alice',
                      text: 'hi',
                      timestamp: DateTime(2025),
                    ),
                  ],
                  typingUsers: const [
                    TypingUser(uid: 'u2', displayName: 'Bob'),
                  ],
                ),
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(chatNotifierProvider.notifier).forceDisconnect();

        final state = container.read(chatNotifierProvider);
        expect(state.status, SessionStatus.disconnected);
        expect(state.sessionId, isNull);
        expect(state.messages, isEmpty);
        expect(state.typingUsers, isEmpty);
      },
    );

    test('forceDisconnect is a no-op when already disconnected', () {
      final container = ProviderContainer(
        overrides: [
          chatNotifierProvider.overrideWith(
            () => _TestChatNotifier(
              initial: const ChatState(status: SessionStatus.disconnected),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(chatNotifierProvider.notifier).forceDisconnect();

      expect(
        container.read(chatNotifierProvider).status,
        SessionStatus.disconnected,
      );
    });
  });

  group('ChatState', () {
    test('initial state has idle status and empty collections', () {
      const state = ChatState();
      expect(state.status, SessionStatus.idle);
      expect(state.sessionId, isNull);
      expect(state.currentUserId, isNull);
      expect(state.currentUserDisplayName, isNull);
      expect(state.currentUserPhotoUrl, isNull);
      expect(state.messages, isEmpty);
      expect(state.typingUsers, isEmpty);
      expect(state.isSending, isFalse);
      expect(state.error, isNull);
    });

    test('copyWith updates status', () {
      const state = ChatState();
      final updated = state.copyWith(status: SessionStatus.chatting);
      expect(updated.status, SessionStatus.chatting);
    });

    test('copyWith sets sessionId', () {
      const state = ChatState();
      final updated = state.copyWith(sessionId: 'room-1');
      expect(updated.sessionId, 'room-1');
    });

    test('copyWith clears sessionId with explicit null (sentinel)', () {
      final state = ChatState(
        status: SessionStatus.chatting,
        sessionId: 'room-1',
      );
      final cleared = state.copyWith(sessionId: null);
      expect(cleared.sessionId, isNull);
    });

    test('copyWith sets currentUserId', () {
      const state = ChatState();
      final updated = state.copyWith(currentUserId: 'user-1');
      expect(updated.currentUserId, 'user-1');
    });

    test('copyWith clears currentUserId with explicit null (sentinel)', () {
      final state = ChatState(currentUserId: 'user-1');
      final cleared = state.copyWith(currentUserId: null);
      expect(cleared.currentUserId, isNull);
    });

    test('copyWith sets and clears error (sentinel)', () {
      const state = ChatState();
      final withError = state.copyWith(error: 'oops');
      expect(withError.error, 'oops');
      final cleared = withError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('copyWith replaces messages list', () {
      final ts = DateTime.now();
      final msgs = [
        ChatMessage(
          id: 'm1',
          senderId: 'u1',
          displayName: 'Alice',
          text: 'hi',
          timestamp: ts,
        ),
      ];
      const state = ChatState();
      final updated = state.copyWith(messages: msgs);
      expect(updated.messages.length, 1);
      expect(updated.messages[0].text, 'hi');
    });

    test('copyWith replaces typingUsers list', () {
      const users = [TypingUser(uid: 'u1', displayName: 'Bob')];
      const state = ChatState();
      final updated = state.copyWith(typingUsers: users);
      expect(updated.typingUsers.length, 1);
    });

    test('copyWith sets currentUserPhotoUrl', () {
      const state = ChatState();
      final updated = state.copyWith(
        currentUserPhotoUrl: 'https://example.com/photo.jpg',
      );
      expect(updated.currentUserPhotoUrl, 'https://example.com/photo.jpg');
    });

    test(
      'copyWith clears currentUserPhotoUrl with explicit null (sentinel)',
      () {
        final state = ChatState(
          currentUserPhotoUrl: 'https://example.com/photo.jpg',
        );
        final cleared = state.copyWith(currentUserPhotoUrl: null);
        expect(cleared.currentUserPhotoUrl, isNull);
      },
    );

    test('copyWith toggles isSending', () {
      const state = ChatState();
      expect(state.copyWith(isSending: true).isSending, isTrue);
      expect(state.copyWith(isSending: false).isSending, isFalse);
    });

    test('copyWith without arguments preserves all fields', () {
      final ts = DateTime.now();
      final msgs = [
        ChatMessage(
          id: 'm1',
          senderId: 'u1',
          displayName: 'Alice',
          text: 'hi',
          timestamp: ts,
        ),
      ];
      final state = ChatState(
        status: SessionStatus.chatting,
        sessionId: 'room-1',
        currentUserId: 'user-1',
        currentUserDisplayName: 'Alice',
        currentUserPhotoUrl: 'https://example.com/photo.jpg',
        messages: msgs,
        typingUsers: const [TypingUser(uid: 'u2', displayName: 'Bob')],
        isSending: true,
        error: 'e',
      );
      final copy = state.copyWith();
      expect(copy.status, SessionStatus.chatting);
      expect(copy.sessionId, 'room-1');
      expect(copy.currentUserId, 'user-1');
      expect(copy.currentUserPhotoUrl, 'https://example.com/photo.jpg');
      expect(copy.messages.length, 1);
      expect(copy.typingUsers.length, 1);
      expect(copy.isSending, isTrue);
      expect(copy.error, 'e');
    });
  });
}
