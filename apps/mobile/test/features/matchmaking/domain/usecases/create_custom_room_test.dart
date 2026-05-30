import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/create_custom_room.dart';

import '../shared_fakes.dart';

void main() {
  group('CreateCustomRoom', () {
    late FakeMatchmakingRepository repo;
    late CreateCustomRoom useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = CreateCustomRoom(repo);
    });

    test('delegates to repository and returns roomId', () async {
      repo.createCustomRoomResult = 'CsT77';

      final roomId = await useCase();

      expect(roomId, 'CsT77');
      expect(repo.createCustomRoomCalls, 1);
    });

    test('forwards backgroundTheme to repository', () async {
      await useCase.call(backgroundTheme: 'kao_tapu');

      expect(repo.createCustomRoomCalls, 1);
      expect(repo.lastCreateCustomRoomBackgroundTheme, 'kao_tapu');
    });

    test('passes null backgroundTheme when not provided', () async {
      await useCase.call();

      expect(repo.lastCreateCustomRoomBackgroundTheme, isNull);
    });

    test('propagates repository exception', () async {
      repo.error = Exception('timeout');

      await expectLater(useCase(), throwsA(isA<Exception>()));
    });
  });
}
