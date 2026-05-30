import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend.dart' as domain;
import 'package:mobile/features/friends/domain/entities/friend_room_status.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/screens/friends_screen.dart';
import 'package:mobile/screens/widgets.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';
import 'package:mobile/shared/offline_card.dart';
import '../shared/fake_network_info.dart';

class _FakeFriendsNotifier extends FriendsNotifier {
  final FriendsState _initial;
  int removeCount = 0;

  _FakeFriendsNotifier({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;

  @override
  Future<void> removeFriend(String friendshipId) async => removeCount++;

  @override
  void clearError() {}
}

class _LoadingToIdleFriendsNotifier extends FriendsNotifier {
  @override
  FriendsState build() => FriendsState(
    friends: [
      domain.Friend(
        friendshipId: 'fship1',
        friendUid: 'uid1',
        friendDisplayName: 'Alice',
        chatRoomId: 'room1',
        friendedAt: DateTime(2024),
      ),
    ],
  );

  @override
  Future<void> removeFriend(String friendshipId) async {
    state = state.copyWith(isLoading: true);
    await Future.microtask(() {});
    state = state.copyWith(isLoading: false);
  }

  @override
  void clearError() {}
}

final _fakeDomainFriend = domain.Friend(
  friendshipId: 'fship1',
  friendUid: 'uid1',
  friendDisplayName: 'Alice',
  chatRoomId: 'room1',
  friendedAt: DateTime(2024),
);

Widget _build({
  required NetworkInfo networkInfo,
  _FakeFriendsNotifier? notifier,
}) {
  final fake = notifier ?? _FakeFriendsNotifier();
  return ProviderScope(
    overrides: [
      networkInfoProvider.overrideWithValue(networkInfo),
      friendsNotifierProvider.overrideWith(() => fake),
    ],
    child: const MaterialApp(home: FriendsScreen()),
  );
}

void main() {
  group('FriendsScreen', () {
    testWidgets('renders without crash when online', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true)),
      );
      expect(find.byType(FriendsScreen), findsOneWidget);
    });

    testWidgets('shows OfflineCard when offline', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: false)),
      );
      await tester.pump();
      expect(find.byType(OfflineCard), findsOneWidget);
    });

    testWidgets('does not show OfflineCard when online', (tester) async {
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true)),
      );
      await tester.pump();
      expect(find.byType(OfflineCard), findsNothing);
    });

    testWidgets('shows friend display name when provider has friends', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [_fakeDomainFriend]),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.text('Alice', skipOffstage: false), findsOneWidget);
    });

    testWidgets('shows no friend cards when provider returns empty list', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true)),
      );
      await tester.pump();
      expect(find.byType(OfflineCard), findsNothing);
      expect(find.text('Alice'), findsNothing);
    });

    testWidgets('calls removeFriend on notifier after confirming Unfriend', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [_fakeDomainFriend]),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unfriend'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();

      expect(fake.removeCount, 1);
    });

    testWidgets('shows last message text from lastMessageMap', (tester) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          friends: [_fakeDomainFriend],
          lastMessageMap: {'room1': 'hey there'},
        ),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.text('hey there'), findsOneWidget);
    });

    testWidgets('shows FriendRoomCard when friend is online and in a room', (
      tester,
    ) async {
      const roomStatus = FriendRoomStatus(
        roomId: 'abc12',
        memberCount: 3,
        maxUsers: 5,
        isLocked: false,
        mode: 'group',
      );
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          friends: [_fakeDomainFriend],
          presenceMap: {'uid1': true},
          roomMap: {'uid1': roomStatus},
        ),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.byType(FriendRoomCard), findsOneWidget);
      expect(find.text('Group Room'), findsOneWidget);
    });

    testWidgets(
      'does not show FriendRoomCard when friend is offline even with room data',
      (tester) async {
        const roomStatus = FriendRoomStatus(
          roomId: 'abc12',
          memberCount: 3,
          maxUsers: 5,
          isLocked: false,
          mode: 'group',
        );
        final fake = _FakeFriendsNotifier(
          initial: FriendsState(
            friends: [_fakeDomainFriend],
            presenceMap: {'uid1': false},
            roomMap: {'uid1': roomStatus},
          ),
        );
        await tester.pumpWidget(
          _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
        );
        await tester.pump();
        expect(find.byType(FriendRoomCard), findsNothing);
      },
    );

    testWidgets('does not show FriendRoomCard when friend has no room', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(
          friends: [_fakeDomainFriend],
          presenceMap: {'uid1': true},
        ),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.byType(FriendRoomCard), findsNothing);
    });

    testWidgets('shows generic person icon placeholder for each friend card', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [_fakeDomainFriend]),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets(
      'shows success dialog after removeFriend loading state clears',
      (tester) async {
        final notifier = _LoadingToIdleFriendsNotifier();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              networkInfoProvider.overrideWithValue(
                FakeNetworkInfo(isOnline: true),
              ),
              friendsNotifierProvider.overrideWith(() => notifier),
            ],
            child: const MaterialApp(home: FriendsScreen()),
          ),
        );
        await tester.pump();

        await tester.tap(find.byType(PopupMenuButton<String>));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Unfriend'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove'));
        await tester.pumpAndSettle();

        expect(find.text('Friend Removed'), findsOneWidget);
      },
    );

    testWidgets('block dialog message does not promise server enforcement', (
      tester,
    ) async {
      final fake = _FakeFriendsNotifier(
        initial: FriendsState(friends: [_fakeDomainFriend]),
      );
      await tester.pumpWidget(
        _build(networkInfo: FakeNetworkInfo(isOnline: true), notifier: fake),
      );
      await tester.pump();

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Block'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('will no longer be able to contact'),
        findsNothing,
      );
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _build(networkInfo: FakeNetworkInfo(isOnline: true)),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
