import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/join_group_room.dart';

import '../shared_fakes.dart';

void main() {
  group('JoinGroupRoom', () {
    late FakeMatchmakingRepository repo;
    late JoinGroupRoom useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = JoinGroupRoom(repo);
    });

    test('delegates to repository and returns result', () async {
      repo.joinGroupRoomResult = (roomId: 'Tt3Xy', isNewRoom: true);

      final result = await useCase();

      expect(result.roomId, 'Tt3Xy');
      expect(result.isNewRoom, true);
      expect(repo.joinGroupRoomCalls, 1);
    });

    test('forwards interestText to repository', () async {
      await useCase.call(interestText: 'cooking');

      expect(repo.joinGroupRoomCalls, 1);
      expect(repo.lastJoinGroupRoomInterest, 'cooking');
    });

    test('passes null interestText when not provided', () async {
      await useCase.call();

      expect(repo.lastJoinGroupRoomInterest, isNull);
    });

    test('forwards backgroundTheme to repository', () async {
      await useCase.call(backgroundTheme: 'lumphini_park');

      expect(repo.joinGroupRoomCalls, 1);
      expect(repo.lastJoinGroupRoomBackgroundTheme, 'lumphini_park');
    });

    test('passes null backgroundTheme when not provided', () async {
      await useCase.call();

      expect(repo.lastJoinGroupRoomBackgroundTheme, isNull);
    });

    test('forwards both interestText and backgroundTheme together', () async {
      await useCase.call(
        interestText: 'cooking',
        backgroundTheme: 'sea_of_cloud',
      );

      expect(repo.lastJoinGroupRoomInterest, 'cooking');
      expect(repo.lastJoinGroupRoomBackgroundTheme, 'sea_of_cloud');
    });

    test('propagates repository exception', () async {
      repo.error = Exception('network error');

      await expectLater(useCase(), throwsA(isA<Exception>()));
    });
  });
}
