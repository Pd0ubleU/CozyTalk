import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/block/domain/entities/blocked_user.dart';

void main() {
  group('BlockedUser', () {
    test('constructs with required fields', () {
      final ts = DateTime(2024, 1, 15);
      final user = BlockedUser(uid: 'uid-1', blockedAt: ts);
      expect(user.uid, 'uid-1');
      expect(user.blockedAt, ts);
    });

    test('displayName defaults to null', () {
      final user = BlockedUser(uid: 'uid-1', blockedAt: DateTime(2024, 1, 15));
      expect(user.displayName, isNull);
    });

    test('accepts optional displayName', () {
      final user = BlockedUser(
        uid: 'uid-2',
        displayName: 'Alice',
        blockedAt: DateTime(2024, 6, 1),
      );
      expect(user.displayName, 'Alice');
    });

    test('blockedAt is preserved exactly', () {
      final ts = DateTime(2025, 3, 20, 12, 30, 45);
      final user = BlockedUser(uid: 'uid-3', blockedAt: ts);
      expect(user.blockedAt, ts);
    });

    test('uid is accessible after construction', () {
      final user = BlockedUser(uid: 'target-uid', blockedAt: DateTime.now());
      expect(user.uid, 'target-uid');
    });
  });
}
