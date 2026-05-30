import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/domain/usecases/join_1v1_pool.dart';

import '../shared_fakes.dart';

void main() {
  group('Join1v1Pool', () {
    late FakeMatchmakingRepository repo;
    late Join1v1Pool useCase;

    setUp(() {
      repo = FakeMatchmakingRepository();
      useCase = Join1v1Pool(repo);
    });

    test('calls repository once', () async {
      await useCase();

      expect(repo.join1v1PoolCalls, 1);
    });

    test('forwards interestText to repository', () async {
      await useCase.call(interestText: 'football');

      expect(repo.join1v1PoolCalls, 1);
      expect(repo.lastJoin1v1PoolInterest, 'football');
    });

    test('passes null interestText when not provided', () async {
      await useCase.call();

      expect(repo.lastJoin1v1PoolInterest, isNull);
    });

    test('forwards backgroundTheme to repository', () async {
      await useCase.call(backgroundTheme: 'kao_tapu');

      expect(repo.join1v1PoolCalls, 1);
      expect(repo.lastJoin1v1PoolBackgroundTheme, 'kao_tapu');
    });

    test('passes null backgroundTheme when not provided', () async {
      await useCase.call();

      expect(repo.lastJoin1v1PoolBackgroundTheme, isNull);
    });

    test('forwards both interestText and backgroundTheme together', () async {
      await useCase.call(
        interestText: 'football',
        backgroundTheme: 'red_lotus_lake',
      );

      expect(repo.lastJoin1v1PoolInterest, 'football');
      expect(repo.lastJoin1v1PoolBackgroundTheme, 'red_lotus_lake');
    });

    test('propagates repository exception', () async {
      repo.error = Exception('already queued');

      await expectLater(useCase(), throwsA(isA<Exception>()));
    });
  });
}
