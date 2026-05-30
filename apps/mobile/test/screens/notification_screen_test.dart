import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/app_user.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/screens/notification_screen.dart';

class _FakeFriendsNotifier extends FriendsNotifier {
  final FriendsState _initial;
  int acceptCount = 0;
  FriendRequest? lastAccepted;
  int declineCount = 0;
  String? lastDeclinedId;

  _FakeFriendsNotifier({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;

  @override
  Future<void> sendFriendRequest(AppUser toUser) async {}

  @override
  Future<void> acceptRequest(FriendRequest request) async {
    acceptCount++;
    lastAccepted = request;
  }

  @override
  Future<void> declineRequest(String requestId) async {
    declineCount++;
    lastDeclinedId = requestId;
  }

  @override
  Future<void> removeFriend(String friendshipId) async {}

  @override
  void clearError() {}
}

Widget _buildScreen(_FakeFriendsNotifier fake) {
  return ProviderScope(
    overrides: [friendsNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: NotificationScreen()),
  );
}

FriendRequest _makeRequest({
  String id = 'req-1',
  String fromUid = 'u1',
  String fromDisplayName = 'Alice',
}) => FriendRequest(
  id: id,
  fromUid: fromUid,
  fromDisplayName: fromDisplayName,
  toUid: 'me',
  toDisplayName: 'Me',
  status: FriendRequestStatus.pending,
  createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
);

void main() {
  group('NotificationScreen', () {
    testWidgets('renders Notifications title', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.text('Notifications'), findsOneWidget);
    });

    testWidgets('shows friend request card with sender name', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [_makeRequest()]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Alice wants to be friends'), findsOneWidget);
    });

    testWidgets('shows Accept and Decline buttons for each request', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [_makeRequest()]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('tapping Accept calls acceptRequest with the request', (
      tester,
    ) async {
      final request = _makeRequest(id: 'req-42');
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Accept'));
      await tester.pump();
      expect(fake.acceptCount, 1);
      expect(fake.lastAccepted?.id, 'req-42');
    });

    testWidgets('tapping Decline calls declineRequest with request id', (
      tester,
    ) async {
      final request = _makeRequest(id: 'req-99');
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(incomingRequests: [request]),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(fake.declineCount, 1);
      expect(fake.lastDeclinedId, 'req-99');
    });

    testWidgets('Accept and Decline are no-ops when isLoading is true', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          incomingRequests: [_makeRequest()],
          isLoading: true,
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      await tester.tap(find.text('Accept'));
      await tester.tap(find.text('Decline'));
      await tester.pump();
      expect(fake.acceptCount, 0);
      expect(fake.declineCount, 0);
    });

    testWidgets('shows multiple request cards', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          incomingRequests: [
            _makeRequest(id: 'r1', fromDisplayName: 'Bob'),
            _makeRequest(id: 'r2', fromDisplayName: 'Carol'),
          ],
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));
      expect(find.text('Bob wants to be friends'), findsOneWidget);
      expect(find.text('Carol wants to be friends'), findsOneWidget);
    });

    testWidgets('shows no notification cards when no requests', (tester) async {
      await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
      expect(find.textContaining('wants to be friends'), findsNothing);
      expect(find.text('Accept'), findsNothing);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildScreen(_FakeFriendsNotifier()));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
