import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/features/matchmaking/presentation/screens/matchmaking_test_screen.dart';

// ── Fake notifier ─────────────────────────────────────────────────────────────

class _FakeMatchmakingNotifier extends MatchmakingNotifier {
  final MatchmakingState _initial;

  int joinGroupRoomCalls = 0;
  int join1v1PoolCalls = 0;
  int createCustomRoomCalls = 0;
  int cancelSearchCalls = 0;
  int leaveRoomCalls = 0;
  int setInterestTextCalls = 0;
  int loadSavedInterestTextCalls = 0;
  int setBackgroundThemeCalls = 0;
  String? lastJoinByIdArg;
  bool? lastSetRoomLockValue;
  String? lastInterestText;
  String? lastBackgroundTheme;

  _FakeMatchmakingNotifier({MatchmakingState? initial})
    : _initial = initial ?? const MatchmakingState();

  @override
  MatchmakingState build() => _initial;

  @override
  Future<void> joinGroupRoom() async => joinGroupRoomCalls++;

  @override
  Future<void> join1v1Pool() async => join1v1PoolCalls++;

  @override
  Future<void> createCustomRoom() async => createCustomRoomCalls++;

  @override
  Future<void> cancelSearch() async => cancelSearchCalls++;

  @override
  Future<void> leaveRoom() async => leaveRoomCalls++;

  @override
  Future<void> joinRoomById(String roomId) async {
    lastJoinByIdArg = roomId;
  }

  @override
  Future<void> setRoomLock({required bool isLocked}) async {
    lastSetRoomLockValue = isLocked;
  }

  @override
  void setInterestText(String text) {
    setInterestTextCalls++;
    lastInterestText = text;
    state = state.copyWith(interestText: text);
  }

  @override
  Future<void> loadSavedInterestText() async {
    loadSavedInterestTextCalls++;
  }

  @override
  void setBackgroundTheme(String? theme) {
    setBackgroundThemeCalls++;
    lastBackgroundTheme = theme;
    state = state.copyWith(backgroundTheme: theme);
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Room _makeRoom({
  RoomType roomType = RoomType.public,
  int memberCount = 2,
  bool isLocked = false,
}) => Room(
  roomId: 'Ab3Kz',
  roomType: roomType,
  mode: RoomMode.group,
  status: RoomStatus.active,
  maxUsers: 5,
  memberCount: memberCount,
  users: List.generate(memberCount, (i) => 'uid$i'),
  isLocked: isLocked,
  createdAt: DateTime(2025),
);

Widget _pump({required _FakeMatchmakingNotifier fake}) {
  return ProviderScope(
    overrides: [matchmakingNotifierProvider.overrideWith(() => fake)],
    child: const MaterialApp(home: MatchmakingTestScreen()),
  );
}

void main() {
  group('MatchmakingTestScreen — state rendering', () {
    testWidgets('shows Idle chip in idle state', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('shows Searching… chip and loading indicator', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(status: MatchmakingStatus.searching),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.text('Searching…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('shows Waiting for 1v1 match… chip', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(status: MatchmakingStatus.waiting1v1),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.text('Waiting for 1v1 match…'), findsOneWidget);
    });

    testWidgets('shows In Room chip when matched', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          currentRoom: _makeRoom(),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.text('In Room'), findsOneWidget);
    });

    testWidgets('shows roomId text when state has roomId', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Tt3Xy',
          currentRoom: _makeRoom(),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.text('Tt3Xy'), findsOneWidget);
    });

    testWidgets('shows member count when currentRoom is set', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          currentRoom: _makeRoom(memberCount: 3),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.textContaining('3/5'), findsOneWidget);
    });

    testWidgets(
      'shows waiting for second person when isNewRoom and memberCount < 2',
      (tester) async {
        final fake = _FakeMatchmakingNotifier(
          initial: MatchmakingState(
            status: MatchmakingStatus.matched,
            roomId: 'Ab3Kz',
            isNewRoom: true,
            currentRoom: _makeRoom(memberCount: 1),
          ),
        );
        await tester.pumpWidget(_pump(fake: fake));

        expect(
          find.textContaining('Waiting for a second person'),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows error text when state has error', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(
          status: MatchmakingStatus.error,
          error: 'Room is locked.',
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.text('Room is locked.'), findsOneWidget);
    });

    testWidgets('does not show Enter Chat button in idle state', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.text('Enter Chat ↗'), findsNothing);
    });

    testWidgets('shows Enter Chat and Leave Room buttons when matched', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          currentRoom: _makeRoom(),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.text('Enter Chat ↗'), findsOneWidget);
      expect(find.text('Leave Room'), findsOneWidget);
    });

    testWidgets('lock toggle visible for custom rooms', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          currentRoom: _makeRoom(roomType: RoomType.custom),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('lock toggle NOT visible for public rooms', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          currentRoom: _makeRoom(roomType: RoomType.public),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.byType(Switch), findsNothing);
    });
  });

  group('MatchmakingTestScreen — interactions', () {
    testWidgets('Find 1v1 button calls join1v1Pool', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.text('Find 1v1'));
      await tester.pump();

      expect(fake.join1v1PoolCalls, 1);
    });

    testWidgets('Find Group Room button calls joinGroupRoom', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.text('Find Group Room'));
      await tester.pump();

      expect(fake.joinGroupRoomCalls, 1);
    });

    testWidgets('Create Custom Room button calls createCustomRoom', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.text('Create Custom Room'));
      await tester.pump();

      expect(fake.createCustomRoomCalls, 1);
    });

    testWidgets('Cancel button calls cancelSearch', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(status: MatchmakingStatus.searching),
      );
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(fake.cancelSearchCalls, 1);
    });

    testWidgets('interest text field is rendered in idle state', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.byKey(const Key('interest_text_field')), findsOneWidget);
    });

    testWidgets('typing into interest field calls setInterestText', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      await tester.enterText(
        find.byKey(const Key('interest_text_field')),
        'football',
      );
      await tester.pump();

      expect(fake.setInterestTextCalls, greaterThan(0));
      expect(fake.lastInterestText, 'football');
    });

    testWidgets('Find 1v1 works when interest field is empty', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.text('Find 1v1'));
      await tester.pump();

      expect(fake.join1v1PoolCalls, 1);
    });

    testWidgets('Find Group Room works when interest field is empty', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.text('Find Group Room'));
      await tester.pump();

      expect(fake.joinGroupRoomCalls, 1);
    });

    testWidgets('pre-populated interestText shows in field', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(interestText: 'music'),
      );
      await tester.pumpWidget(_pump(fake: fake));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('interest_text_field')),
      );
      expect(field.controller?.text ?? '', 'music');
    });

    testWidgets('entering 5 chars and tapping Join by ID calls joinRoomById', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      for (var i = 0; i < 5; i++) {
        await tester.ensureVisible(find.byKey(Key('room_id_field_$i')));
        await tester.enterText(find.byKey(Key('room_id_field_$i')), 'ABCDE'[i]);
        await tester.pump();
      }

      await tester.ensureVisible(find.text('Join by ID'));
      await tester.tap(find.text('Join by ID'));
      await tester.pump();

      expect(fake.lastJoinByIdArg, isNotNull);
      expect(fake.lastJoinByIdArg!.length, 5);
    });

    testWidgets('Leave Room button calls leaveRoom', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          currentRoom: _makeRoom(),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      await tester.ensureVisible(find.text('Leave Room'));
      await tester.tap(find.text('Leave Room'));
      await tester.pump();

      expect(fake.leaveRoomCalls, 1);
    });

    testWidgets('lock toggle triggers setRoomLock', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          currentRoom: _makeRoom(roomType: RoomType.custom, isLocked: false),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      await tester.ensureVisible(find.byType(Switch));
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(fake.lastSetRoomLockValue, isNotNull);
    });
  });

  group('MatchmakingTestScreen — background theme selector', () {
    testWidgets('renders all four theme chips', (tester) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.byKey(const Key('theme_chip_kao_tapu')), findsOneWidget);
      expect(
        find.byKey(const Key('theme_chip_red_lotus_lake')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('theme_chip_sea_of_cloud')), findsOneWidget);
      expect(find.byKey(const Key('theme_chip_lumphini_park')), findsOneWidget);
    });

    testWidgets('tapping a chip calls setBackgroundTheme with its id', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.byKey(const Key('theme_chip_kao_tapu')));
      await tester.pump();

      expect(fake.setBackgroundThemeCalls, 1);
      expect(fake.lastBackgroundTheme, 'kao_tapu');
    });

    testWidgets(
      'tapping the active chip deselects it (calls setBackgroundTheme(null))',
      (tester) async {
        final fake = _FakeMatchmakingNotifier(
          initial: const MatchmakingState(backgroundTheme: 'red_lotus_lake'),
        );
        await tester.pumpWidget(_pump(fake: fake));

        await tester.tap(find.byKey(const Key('theme_chip_red_lotus_lake')));
        await tester.pump();

        expect(fake.setBackgroundThemeCalls, 1);
        expect(fake.lastBackgroundTheme, isNull);
      },
    );

    testWidgets('chips are disabled when matchmaking is in progress', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(status: MatchmakingStatus.waiting1v1),
      );
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.byKey(const Key('theme_chip_kao_tapu')));
      await tester.pump();

      expect(fake.setBackgroundThemeCalls, 0);
    });

    testWidgets('chips are disabled when matched', (tester) async {
      final fake = _FakeMatchmakingNotifier(
        initial: MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          currentRoom: _makeRoom(),
        ),
      );
      await tester.pumpWidget(_pump(fake: fake));

      await tester.tap(find.byKey(const Key('theme_chip_sea_of_cloud')));
      await tester.pump();

      expect(fake.setBackgroundThemeCalls, 0);
    });

    testWidgets('selected chip is shown as selected in debug panel', (
      tester,
    ) async {
      final fake = _FakeMatchmakingNotifier(
        initial: const MatchmakingState(backgroundTheme: 'lumphini_park'),
      );
      await tester.pumpWidget(_pump(fake: fake));

      expect(find.textContaining('lumphini_park'), findsWidgets);
    });
  });
}
