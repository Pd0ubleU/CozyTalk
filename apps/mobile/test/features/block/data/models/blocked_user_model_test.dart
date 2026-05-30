import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/block/data/models/blocked_user_model.dart';

void main() {
  group('BlockedUserModel', () {
    group('fromJson', () {
      test('constructs with all fields present (string timestamp)', () {
        final model = BlockedUserModel.fromJson({
          'blockedUid': 'uid-1',
          'displayName': 'Alice',
          'blockedAt': '2024-01-15T10:00:00.000Z',
        });
        expect(model.blockedUid, 'uid-1');
        expect(model.displayName, 'Alice');
        expect(model.blockedAt, DateTime.parse('2024-01-15T10:00:00.000Z'));
      });

      test('handles null displayName', () {
        final model = BlockedUserModel.fromJson({
          'blockedUid': 'uid-2',
          'displayName': null,
          'blockedAt': '2024-01-15T10:00:00.000Z',
        });
        expect(model.blockedUid, 'uid-2');
        expect(model.displayName, isNull);
      });

      test('handles missing displayName key', () {
        final model = BlockedUserModel.fromJson({
          'blockedUid': 'uid-3',
          'blockedAt': '2024-06-01T00:00:00.000Z',
        });
        expect(model.displayName, isNull);
      });

      test('handles integer millisecond timestamp', () {
        final ms = DateTime(2024, 3, 10).millisecondsSinceEpoch;
        final model = BlockedUserModel.fromJson({
          'blockedUid': 'uid-4',
          'blockedAt': ms,
        });
        expect(model.blockedAt, DateTime.fromMillisecondsSinceEpoch(ms));
      });

      test('ignores unknown fields gracefully', () {
        final model = BlockedUserModel.fromJson({
          'blockedUid': 'uid-5',
          'blockedAt': '2024-01-15T10:00:00.000Z',
          'unknownField': 'should be ignored',
          'anotherUnknown': 42,
        });
        expect(model.blockedUid, 'uid-5');
      });
    });

    group('toEntity', () {
      test('maps blockedUid to entity uid', () {
        final model = BlockedUserModel(
          blockedUid: 'uid-6',
          blockedAt: DateTime(2024, 1, 15),
        );
        final entity = model.toEntity();
        expect(entity.uid, 'uid-6');
      });

      test('maps displayName to entity displayName', () {
        final model = BlockedUserModel(
          blockedUid: 'uid-7',
          displayName: 'Bob',
          blockedAt: DateTime(2024, 1, 15),
        );
        final entity = model.toEntity();
        expect(entity.displayName, 'Bob');
      });

      test('preserves null displayName in entity', () {
        final model = BlockedUserModel(
          blockedUid: 'uid-8',
          blockedAt: DateTime(2024, 1, 15),
        );
        final entity = model.toEntity();
        expect(entity.displayName, isNull);
      });

      test('maps blockedAt to entity blockedAt', () {
        final ts = DateTime(2025, 6, 20, 9, 0);
        final model = BlockedUserModel(blockedUid: 'uid-9', blockedAt: ts);
        final entity = model.toEntity();
        expect(entity.blockedAt, ts);
      });

      test('full round-trip: all fields map correctly', () {
        final ts = DateTime(2024, 2, 28);
        final model = BlockedUserModel(
          blockedUid: 'uid-10',
          displayName: 'Carol',
          blockedAt: ts,
        );
        final entity = model.toEntity();
        expect(entity.uid, 'uid-10');
        expect(entity.displayName, 'Carol');
        expect(entity.blockedAt, ts);
      });
    });
  });
}
