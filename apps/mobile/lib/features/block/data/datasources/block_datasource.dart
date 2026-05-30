import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/blocked_user_model.dart';

abstract class BlockDatasource {
  Stream<List<BlockedUserModel>> watchBlockedUsers(String uid);
  Future<void> blockUser(
    String ownerUid,
    String targetUid, {
    String? displayName,
  });
  Future<void> unblockUser(String ownerUid, String targetUid);
}

class BlockDatasourceImpl implements BlockDatasource {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  BlockDatasourceImpl(this._firestore, this._functions);

  @override
  Stream<List<BlockedUserModel>> watchBlockedUsers(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('blocked')
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => BlockedUserModel.fromJson(
                  Map<String, dynamic>.from(d.data()),
                ),
              )
              .toList(),
        );
  }

  @override
  Future<void> blockUser(
    String ownerUid,
    String targetUid, {
    String? displayName,
  }) async {
    final result = await _functions.httpsCallable('blockUser').call<Map>({
      'targetUid': targetUid,
      if (displayName != null) 'displayName': displayName,
    });
    final data = Map<String, dynamic>.from(result.data);
    if (data['success'] == false) {
      throw Exception(data['reason'] ?? 'Failed to block user');
    }
  }

  @override
  Future<void> unblockUser(String ownerUid, String targetUid) async {
    await _functions.httpsCallable('unblockUser').call<Map>({
      'targetUid': targetUid,
    });
  }
}
