import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/friends/domain/entities/friend_room_status.dart';

void main() {
  group('FriendRoomStatus', () {
    test('constructs with all required fields', () {
      const status = FriendRoomStatus(
        roomId: 'abc12',
        memberCount: 3,
        maxUsers: 5,
        isLocked: false,
        mode: 'group',
      );
      expect(status.roomId, 'abc12');
      expect(status.memberCount, 3);
      expect(status.maxUsers, 5);
      expect(status.isLocked, isFalse);
      expect(status.mode, 'group');
    });

    test('preserves 1v1 mode', () {
      const status = FriendRoomStatus(
        roomId: 'r1',
        memberCount: 2,
        maxUsers: 2,
        isLocked: false,
        mode: '1v1',
      );
      expect(status.mode, '1v1');
      expect(status.maxUsers, 2);
    });

    test('isLocked true is preserved', () {
      const status = FriendRoomStatus(
        roomId: 'r2',
        memberCount: 1,
        maxUsers: 5,
        isLocked: true,
        mode: 'group',
      );
      expect(status.isLocked, isTrue);
    });

    test('memberCount zero is preserved', () {
      const status = FriendRoomStatus(
        roomId: 'r3',
        memberCount: 0,
        maxUsers: 5,
        isLocked: false,
        mode: 'group',
      );
      expect(status.memberCount, 0);
    });
  });
}
