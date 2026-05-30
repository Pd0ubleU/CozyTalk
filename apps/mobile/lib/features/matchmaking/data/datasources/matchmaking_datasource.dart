import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../domain/entities/room.dart';
import '../models/room_model.dart';

abstract class MatchmakingDatasource {
  Future<({String roomId, bool isNewRoom})> joinGroupRoom({
    String? interestText,
    String? backgroundTheme,
  });
  Future<String> createCustomRoom({String? backgroundTheme});
  Future<({String roomId, RoomMode mode, RoomType roomType})> joinRoomById(
    String roomId,
  );
  Future<void> leaveRoom(String roomId);
  Future<void> join1v1Pool({String? interestText, String? backgroundTheme});
  Future<bool> cancel1v1Pool();
  Future<void> setRoomLock({required String roomId, required bool isLocked});
  Stream<RoomModel?> watchRoom(String roomId);
  Stream<String?> watch1v1Match(String uid);

  /// Registers RTDB onDisconnect cleanup for the given room.
  /// Call this after any room join so browser-close auto-cleans RTDB membership.
  Future<void> registerRoomPresence(String roomId);

  /// Returns the UID of the currently signed-in user, or null if not signed in.
  String? getCurrentUserId();
}

class MatchmakingDatasourceImpl implements MatchmakingDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseDatabase _rtdb;
  final FirebaseAuth _auth;

  MatchmakingDatasourceImpl(
    this._firestore,
    this._functions,
    this._rtdb,
    this._auth,
  );

  @override
  Future<({String roomId, bool isNewRoom})> joinGroupRoom({
    String? interestText,
    String? backgroundTheme,
  }) async {
    final result = await _functions.httpsCallable('joinGroupRoom').call({
      if (interestText != null && interestText.isNotEmpty)
        'interestText': interestText,
      if (backgroundTheme != null) 'backgroundTheme': backgroundTheme,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final roomId = data['roomId'] as String;
    await _registerDisconnect(roomId);
    return (roomId: roomId, isNewRoom: data['isNewRoom'] as bool);
  }

  @override
  Future<String> createCustomRoom({String? backgroundTheme}) async {
    final result = await _functions.httpsCallable('createCustomRoom').call({
      if (backgroundTheme != null) 'backgroundTheme': backgroundTheme,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final roomId = data['roomId'] as String;
    await _registerDisconnect(roomId);
    return roomId;
  }

  @override
  Future<({String roomId, RoomMode mode, RoomType roomType})> joinRoomById(
    String roomId,
  ) async {
    final result = await _functions.httpsCallable('joinRoomById').call({
      'roomId': roomId,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final resolvedRoomId = data['roomId'] as String;
    await _registerDisconnect(resolvedRoomId);
    return (
      roomId: resolvedRoomId,
      mode: data['mode'] == '1v1' ? RoomMode.oneToOne : RoomMode.group,
      roomType: data['roomType'] == 'custom'
          ? RoomType.custom
          : RoomType.public,
    );
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    await _functions.httpsCallable('leaveRoom').call({'roomId': roomId});
  }

  @override
  Future<void> join1v1Pool({
    String? interestText,
    String? backgroundTheme,
  }) async {
    await _functions.httpsCallable('join1v1Pool').call({
      if (interestText != null && interestText.isNotEmpty)
        'interestText': interestText,
      if (backgroundTheme != null) 'backgroundTheme': backgroundTheme,
    });
    // Write RTDB pool presence so onDisconnect auto-removes the waiting_pool entry
    // when the browser closes without pressing Cancel.
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      final ref = _rtdb.ref('pool_presence/$uid');
      await ref.onDisconnect().remove();
      await ref.set(true);
    }
  }

  @override
  Future<bool> cancel1v1Pool() async {
    final result = await _functions.httpsCallable('cancel1v1Pool').call({});
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      await _rtdb.ref('pool_presence/$uid').remove();
    }
    final data = Map<String, dynamic>.from(result.data as Map);
    return data['success'] as bool? ?? false;
  }

  @override
  Future<void> setRoomLock({
    required String roomId,
    required bool isLocked,
  }) async {
    await _functions.httpsCallable('setRoomLock').call({
      'roomId': roomId,
      'isLocked': isLocked,
    });
  }

  @override
  Stream<RoomModel?> watchRoom(String roomId) {
    return _firestore
        .collection('rooms')
        .doc(roomId)
        .withConverter<RoomModel?>(
          fromFirestore: (snap, _) {
            if (!snap.exists || snap.data() == null) return null;
            return RoomModel.fromFirestore(snap);
          },
          toFirestore: (_, options) => {},
        )
        .snapshots()
        .map((snap) => snap.data());
  }

  @override
  Stream<String?> watch1v1Match(String uid) {
    return _firestore.collection('waiting_pool').doc(uid).snapshots().map((
      snap,
    ) {
      if (!snap.exists) return null;
      final data = snap.data();
      if (data == null) return null;
      if (data['status'] != 'matched') return null;
      return data['roomId'] as String?;
    });
  }

  @override
  Future<void> registerRoomPresence(String roomId) =>
      _registerDisconnect(roomId);

  @override
  String? getCurrentUserId() => _auth.currentUser?.uid;

  Future<void> _registerDisconnect(String roomId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      // Removing rooms/{roomId}/members/{uid} triggers the cleanupMember CF
      // which decrements memberCount in Firestore. Rules now allow self-delete.
      await Future.wait([
        _rtdb.ref('rooms/$roomId/members/$uid').onDisconnect().remove(),
        _rtdb.ref('typing/$roomId/$uid').onDisconnect().remove(),
        _rtdb.ref('presence/$roomId/$uid').onDisconnect().remove(),
      ]);
    } catch (_) {
      // Non-fatal.
    }
  }
}
