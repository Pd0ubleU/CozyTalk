import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/entities/matchmaking_status.dart';
import 'package:mobile/features/matchmaking/domain/entities/room.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';

Room _activeRoom() => Room(
  roomId: 'Rm001',
  roomType: RoomType.public,
  mode: RoomMode.group,
  status: RoomStatus.active,
  maxUsers: 5,
  memberCount: 2,
  users: const ['uid1', 'uid2'],
  isLocked: false,
  createdAt: DateTime(2025),
);

void main() {
  group('MatchmakingState', () {
    test('initial state has idle status and all fields at defaults', () {
      const s = MatchmakingState();

      expect(s.status, MatchmakingStatus.idle);
      expect(s.roomId, isNull);
      expect(s.isNewRoom, false);
      expect(s.currentRoom, isNull);
      expect(s.error, isNull);
      expect(s.interestText, '');
    });

    group('copyWith', () {
      test('updates status', () {
        const s = MatchmakingState();
        final updated = s.copyWith(status: MatchmakingStatus.searching);

        expect(updated.status, MatchmakingStatus.searching);
      });

      test('sets roomId', () {
        const s = MatchmakingState();
        final updated = s.copyWith(roomId: 'Ab3Kz');

        expect(updated.roomId, 'Ab3Kz');
      });

      test('clears roomId with explicit null (sentinel guard)', () {
        final s = MatchmakingState(roomId: 'Ab3Kz');
        final cleared = s.copyWith(roomId: null);

        expect(cleared.roomId, isNull);
      });

      test('preserves roomId when not specified', () {
        final s = MatchmakingState(roomId: 'Ab3Kz');
        final updated = s.copyWith(status: MatchmakingStatus.matched);

        expect(updated.roomId, 'Ab3Kz');
      });

      test('sets currentRoom', () {
        final room = _activeRoom();
        const s = MatchmakingState();
        final updated = s.copyWith(currentRoom: room);

        expect(updated.currentRoom, room);
      });

      test('clears currentRoom with explicit null (sentinel guard)', () {
        final s = MatchmakingState(currentRoom: _activeRoom());
        final cleared = s.copyWith(currentRoom: null);

        expect(cleared.currentRoom, isNull);
      });

      test('preserves currentRoom when not specified', () {
        final room = _activeRoom();
        final s = MatchmakingState(currentRoom: room);
        final updated = s.copyWith(status: MatchmakingStatus.matched);

        expect(updated.currentRoom, room);
      });

      test('sets error', () {
        const s = MatchmakingState();
        final updated = s.copyWith(error: 'something went wrong');

        expect(updated.error, 'something went wrong');
      });

      test('clears error with explicit null (sentinel guard)', () {
        final s = MatchmakingState(error: 'old error');
        final cleared = s.copyWith(error: null);

        expect(cleared.error, isNull);
      });

      test('preserves error when not specified', () {
        final s = MatchmakingState(error: 'old error');
        final updated = s.copyWith(status: MatchmakingStatus.error);

        expect(updated.error, 'old error');
      });

      test('updates isNewRoom', () {
        const s = MatchmakingState(isNewRoom: false);
        final updated = s.copyWith(isNewRoom: true);

        expect(updated.isNewRoom, true);
      });

      test('sets interestText', () {
        const s = MatchmakingState();
        final updated = s.copyWith(interestText: 'football');

        expect(updated.interestText, 'football');
      });

      test('preserves interestText when not specified', () {
        const s = MatchmakingState(interestText: 'cooking');
        final updated = s.copyWith(status: MatchmakingStatus.searching);

        expect(updated.interestText, 'cooking');
      });

      test('clears interestText by setting empty string', () {
        const s = MatchmakingState(interestText: 'football');
        final cleared = s.copyWith(interestText: '');

        expect(cleared.interestText, '');
      });

      test('sets backgroundTheme', () {
        const s = MatchmakingState();
        final updated = s.copyWith(backgroundTheme: 'kao_tapu');

        expect(updated.backgroundTheme, 'kao_tapu');
      });

      test('clears backgroundTheme with explicit null (sentinel guard)', () {
        final s = MatchmakingState(backgroundTheme: 'kao_tapu');
        final cleared = s.copyWith(backgroundTheme: null);

        expect(cleared.backgroundTheme, isNull);
      });

      test('preserves backgroundTheme when not specified', () {
        final s = MatchmakingState(backgroundTheme: 'red_lotus_lake');
        final updated = s.copyWith(status: MatchmakingStatus.searching);

        expect(updated.backgroundTheme, 'red_lotus_lake');
      });

      test('preserves all fields when called with no args', () {
        final room = _activeRoom();
        final s = MatchmakingState(
          status: MatchmakingStatus.matched,
          roomId: 'Ab3Kz',
          isNewRoom: true,
          currentRoom: room,
          error: 'err',
          interestText: 'music',
          backgroundTheme: 'sea_of_cloud',
        );

        final unchanged = s.copyWith();

        expect(unchanged.status, MatchmakingStatus.matched);
        expect(unchanged.roomId, 'Ab3Kz');
        expect(unchanged.isNewRoom, true);
        expect(unchanged.currentRoom, room);
        expect(unchanged.error, 'err');
        expect(unchanged.interestText, 'music');
        expect(unchanged.backgroundTheme, 'sea_of_cloud');
      });
    });
  });

  group('MatchmakingState initial defaults', () {
    test('backgroundTheme defaults to null', () {
      const s = MatchmakingState();

      expect(s.backgroundTheme, isNull);
    });
  });
}
