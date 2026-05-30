import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/friend.dart';
import 'package:mobile/screens/friend_chat_screen.dart';
import 'package:mobile/theme/app_routes.dart';

final _testFriend = Friend(
  name: 'Alice',
  username: 'alice99',
  lastMessage: 'Hey!',
  isOnline: true,
);

final _blockedFriend = Friend(
  name: 'Bob',
  username: 'bob77',
  lastMessage: '',
  isOnline: false,
  isBlocked: true,
);

Future<void> _pump(WidgetTester tester, {Friend? friend}) async {
  friend ??= _testFriend;
  await tester.pumpWidget(
    MaterialApp(
      routes: {
        '/': (_) => Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.pushNamed(
              ctx,
              AppRoutes.friendChat,
              arguments: friend,
            ),
            child: const Text('go'),
          ),
        ),
        AppRoutes.friendChat: (_) => const FriendChatScreen(),
        AppRoutes.groupChatScreen: (_) =>
            const Scaffold(body: Text('group-chat')),
      },
    ),
  );
  await tester.tap(find.text('go'));
  await tester.pumpAndSettle();
}

void main() {
  group('FriendChatScreen', () {
    testWidgets('renders without error', (tester) async {
      await _pump(tester);
      expect(find.byType(FriendChatScreen), findsOneWidget);
    });

    testWidgets('shows friend username in header', (tester) async {
      await _pump(tester);
      expect(find.text('alice99'), findsOneWidget);
    });

    testWidgets('shows online status in header', (tester) async {
      await _pump(tester);
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('shows message input field when friend is not blocked', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows blocked bar when friend is blocked', (tester) async {
      await _pump(tester, friend: _blockedFriend);
      expect(
        find.text('You can no longer send messages in this chat.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('shows offline status for offline friend', (tester) async {
      await _pump(tester, friend: _blockedFriend);
      expect(find.text('Offline'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await _pump(tester);
          expect(find.bySemanticsLabel('Send message'), findsOneWidget);
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
