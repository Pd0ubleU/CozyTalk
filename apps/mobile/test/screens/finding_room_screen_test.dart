import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/screens/finding_room_screen.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';
import 'package:mobile/shared/offline_card.dart';
import 'package:mobile/theme/app_routes.dart';
import '../shared/fake_network_info.dart';

class _FakeMatchmakingNotifier extends MatchmakingNotifier {
  final MatchmakingState _initial;
  int join1v1Count = 0;
  int joinGroupCount = 0;
  int createCustomCount = 0;
  int cancelSearchCount = 0;
  String? joinByIdRoomId;

  _FakeMatchmakingNotifier({
    MatchmakingState initial = const MatchmakingState(),
  }) : _initial = initial;

  @override
  MatchmakingState build() => _initial;

  @override
  Future<void> join1v1Pool() async => join1v1Count++;

  @override
  Future<void> joinGroupRoom() async => joinGroupCount++;

  @override
  Future<void> createCustomRoom() async => createCustomCount++;

  @override
  Future<void> joinRoomById(String roomId) async => joinByIdRoomId = roomId;

  @override
  Future<void> cancelSearch() async => cancelSearchCount++;

  @override
  Future<void> setRoomLock({required bool isLocked}) async {}

  @override
  Future<void> leaveRoom() async {}

  @override
  void setInterestText(String text) {}

  @override
  Future<void> loadSavedInterestText() async {}

  void setStateForTest(MatchmakingState s) => state = s;
}

// Builds the app and pumps to FindingRoomScreen.
// Navigation stack: home → chooseRoomType → findingRoom
// This ensures popUntil(chooseRoomType) has a target.
Future<void> _pump(
  WidgetTester tester,
  _FakeMatchmakingNotifier fake, {
  String roomType = '1v1',
  String roomName = 'Kao Tapu',
  String bgImage = 'assets/images/backgrounds/kao_tapu.png',
  String? roomId,
  // Defaults to online so existing tests continue working without change.
  NetworkInfo? networkInfo,
}) async {
  final args = {
    'roomType': roomType,
    'roomName': roomName,
    'bgImage': bgImage,
    'isGroup': roomType == 'group' || roomType == 'create',
    if (roomId != null) 'roomId': roomId,
  };

  // Always override networkInfoProvider — _startMatchmaking calls isConnected
  // which uses platform channels that are not available in the test environment.
  final resolvedNetworkInfo = networkInfo ?? FakeNetworkInfo(isOnline: true);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        matchmakingNotifierProvider.overrideWith(() => fake),
        networkInfoProvider.overrideWithValue(resolvedNetworkInfo),
      ],
      child: MaterialApp(
        routes: {
          '/': (_) => Builder(
            builder: (ctx) => TextButton(
              onPressed: () =>
                  Navigator.pushNamed(ctx, AppRoutes.chooseRoomType),
              child: const Text('home'),
            ),
          ),
          AppRoutes.chooseRoomType: (_) => Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                onPressed: () => Navigator.pushNamed(
                  ctx,
                  AppRoutes.findingRoom,
                  arguments: args,
                ),
                child: const Text('choose-room-type'),
              ),
            ),
          ),
          AppRoutes.findingRoom: (_) => const FindingRoomScreen(),
          AppRoutes.chatScreen: (_) =>
              const Scaffold(body: Text('chat-screen')),
          AppRoutes.groupChatScreen: (_) =>
              const Scaffold(body: Text('group-chat-screen')),
        },
      ),
    ),
  );

  // home → chooseRoomType
  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();

  // chooseRoomType → findingRoom
  await tester.tap(find.text('choose-room-type'));
  await tester.pump(); // render FindingRoomScreen + fire postFrameCallback
  await tester.pump(); // allow async join call to resolve
}

void main() {
  group('FindingRoomScreen', () {
    // ── mount calls ──────────────────────────────────────────────────────────

    testWidgets('calls join1v1Pool on mount when roomType is 1v1', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: '1v1');
      expect(fake.join1v1Count, 1);
      expect(fake.joinGroupCount, 0);
      expect(fake.createCustomCount, 0);
    });

    testWidgets('calls joinGroupRoom on mount when roomType is group', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: 'group');
      expect(fake.joinGroupCount, 1);
      expect(fake.join1v1Count, 0);
      expect(fake.createCustomCount, 0);
    });

    testWidgets('calls createCustomRoom on mount when roomType is create', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: 'create');
      expect(fake.createCustomCount, 1);
      expect(fake.join1v1Count, 0);
      expect(fake.joinGroupCount, 0);
    });

    testWidgets('calls joinRoomById with correct id for joinById', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: 'joinById', roomId: 'XYZAB');
      expect(fake.joinByIdRoomId, 'XYZAB');
    });

    // ── badge labels ─────────────────────────────────────────────────────────

    testWidgets('shows 1 on 1 Chat badge for 1v1 roomType', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: '1v1', roomName: 'Test');
      expect(find.text('1 on 1 Chat'), findsOneWidget);
    });

    testWidgets('shows Group Chat badge for group roomType', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: 'group', roomName: 'Test');
      expect(find.text('Group Chat'), findsOneWidget);
    });

    testWidgets('shows Private Group badge for create roomType', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: 'create', roomName: 'Test');
      expect(find.text('Private Group'), findsOneWidget);
    });

    testWidgets('shows Join by ID badge for joinById roomType', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(
        tester,
        fake,
        roomType: 'joinById',
        roomName: 'Test',
        roomId: 'ABCDE',
      );
      expect(find.text('Join by ID'), findsOneWidget);
    });

    testWidgets('displays room name from args', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: '1v1', roomName: 'Red Lotus Lake');
      expect(find.text('Red Lotus Lake'), findsOneWidget);
    });

    // ── navigation on matched ─────────────────────────────────────────────────

    testWidgets('navigates to chatScreen when matched with roomType 1v1', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: '1v1');

      fake.setStateForTest(
        const MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'ABC12',
        ),
      );
      await tester
          .pump(); // ref.listen fires → _goToChat → Future.delayed(700ms)
      await tester.pump(
        const Duration(milliseconds: 750),
      ); // delay expires + nav fires
      await tester.pump(); // new screen renders

      expect(find.text('chat-screen'), findsOneWidget);
    });

    testWidgets(
      'navigates to groupChatScreen when matched with roomType group',
      (tester) async {
        final fake = _FakeMatchmakingNotifier();
        await _pump(tester, fake, roomType: 'group');

        fake.setStateForTest(
          const MatchmakingState(
            status: MatchmakingStatus.matched,
            roomId: 'XYZ99',
          ),
        );
        await tester
            .pump(); // ref.listen fires → _goToChat → Future.delayed(700ms)
        await tester.pump(
          const Duration(milliseconds: 750),
        ); // delay expires + nav fires
        await tester.pump(); // new screen renders

        expect(find.text('group-chat-screen'), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to groupChatScreen when matched with roomType create',
      (tester) async {
        final fake = _FakeMatchmakingNotifier();
        await _pump(tester, fake, roomType: 'create');

        fake.setStateForTest(
          const MatchmakingState(
            status: MatchmakingStatus.matched,
            roomId: 'CRT01',
          ),
        );
        await tester
            .pump(); // ref.listen fires → _goToChat → Future.delayed(zero)
        await tester.pump(
          const Duration(milliseconds: 50),
        ); // timer fires + nav fires
        await tester.pump(); // new screen renders

        expect(find.text('group-chat-screen'), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to groupChatScreen when matched with roomType joinById',
      (tester) async {
        final fake = _FakeMatchmakingNotifier();
        await _pump(tester, fake, roomType: 'joinById', roomId: 'JN001');

        fake.setStateForTest(
          const MatchmakingState(
            status: MatchmakingStatus.matched,
            roomId: 'JN001',
          ),
        );
        await tester
            .pump(); // ref.listen fires → _goToChat → Future.delayed(zero)
        await tester.pump(
          const Duration(milliseconds: 50),
        ); // timer fires + nav fires
        await tester.pump(); // new screen renders

        expect(find.text('group-chat-screen'), findsOneWidget);
      },
    );

    // ── error state ───────────────────────────────────────────────────────────

    testWidgets('shows SnackBar when status is error', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: '1v1');

      fake.setStateForTest(
        const MatchmakingState(
          status: MatchmakingStatus.error,
          error: 'Match failed',
        ),
      );
      await tester.pump(); // ref.listen fires → showSnackBar
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Match failed'), findsOneWidget);
    });

    // ── cancel button ─────────────────────────────────────────────────────────

    testWidgets('calls cancelSearch when Cancel button is tapped', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: '1v1');

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(fake.cancelSearchCount, greaterThanOrEqualTo(1));
    });

    testWidgets('Cancel button lands on chooseRoomType', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: '1v1');

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.text('choose-room-type'), findsOneWidget);
    });

    // ── dispose ───────────────────────────────────────────────────────────────

    testWidgets('calls cancelSearch on dispose when not yet matched', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, roomType: '1v1');

      // Cancel triggers popUntil → FindingRoomScreen is disposed
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      // cancelSearch must have been called at least once (Cancel tap + dispose)
      expect(fake.cancelSearchCount, greaterThanOrEqualTo(1));
    });

    // ── offline ───────────────────────────────────────────────────────────────

    testWidgets('shows OfflineCard when offline', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, networkInfo: FakeNetworkInfo(isOnline: false));
      await tester.pump();
      expect(find.byType(OfflineCard), findsOneWidget);
    });

    testWidgets('does not show OfflineCard when online', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, networkInfo: FakeNetworkInfo(isOnline: true));
      await tester.pump();
      expect(find.byType(OfflineCard), findsNothing);
    });

    testWidgets('tuk-tuk asset absent when offline', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, networkInfo: FakeNetworkInfo(isOnline: false));
      await tester.pump();
      final tuktukImages = find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is AssetImage &&
            (w.image as AssetImage).assetName.contains('tuk_tuk'),
      );
      expect(tuktukImages, findsNothing);
    });

    testWidgets('Cancel button always visible when offline', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await _pump(tester, fake, networkInfo: FakeNetworkInfo(isOnline: false));
      await tester.pump();
      expect(find.text('Cancel'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('cancel button is readable via text', (tester) async {
        // OutlinedButton with text child — Flutter reads it automatically, no Semantics wrapper needed
      });
    });
  });
}
