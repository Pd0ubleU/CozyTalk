import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/block_datasource.dart';
import '../../data/repositories/block_repository_impl.dart';
import '../../domain/entities/blocked_user.dart';
import '../../domain/repositories/block_repository.dart';
import '../../domain/usecases/block_user.dart';
import '../../domain/usecases/unblock_user.dart';
import '../../domain/usecases/watch_blocked_users.dart';

const _sentinel = Object();

// ── DI wiring ──────────────────────────────────────────────────────────────

final _blockDatasourceProvider = Provider<BlockDatasource>(
  (ref) => BlockDatasourceImpl(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: 'us-central1'),
  ),
);

final _blockRepositoryProvider = Provider<BlockRepository>(
  (ref) => BlockRepositoryImpl(ref.watch(_blockDatasourceProvider)),
);

final _watchBlockedUsersProvider = Provider<WatchBlockedUsers>(
  (ref) => WatchBlockedUsers(ref.watch(_blockRepositoryProvider)),
);

final _blockUserProvider = Provider<BlockUser>(
  (ref) => BlockUser(ref.watch(_blockRepositoryProvider)),
);

final _unblockUserProvider = Provider<UnblockUser>(
  (ref) => UnblockUser(ref.watch(_blockRepositoryProvider)),
);

// ── State ─────────────────────────────────────────────────────────────────

enum BlockStatus { idle, loading, loaded, error }

class BlockState {
  final BlockStatus status;
  final List<BlockedUser> blockedUsers;
  final bool isSubmitting;
  final String? error;

  const BlockState({
    this.status = BlockStatus.idle,
    this.blockedUsers = const [],
    this.isSubmitting = false,
    this.error,
  });

  BlockState copyWith({
    BlockStatus? status,
    List<BlockedUser>? blockedUsers,
    bool? isSubmitting,
    Object? error = _sentinel,
  }) => BlockState(
    status: status ?? this.status,
    blockedUsers: blockedUsers ?? this.blockedUsers,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    error: error == _sentinel ? this.error : error as String?,
  );
}

// ── Provider ──────────────────────────────────────────────────────────────

final blockNotifierProvider = NotifierProvider<BlockNotifier, BlockState>(
  BlockNotifier.new,
);

class BlockNotifier extends Notifier<BlockState> {
  StreamSubscription<List<BlockedUser>>? _sub;

  @override
  BlockState build() {
    ref.onDispose(() => _sub?.cancel());
    final uid = ref.watch(authNotifierProvider).user?.uid;
    if (uid == null) return const BlockState();

    _sub = ref
        .read(_watchBlockedUsersProvider)
        .call(uid)
        .listen(
          (users) => state = state.copyWith(
            status: BlockStatus.loaded,
            blockedUsers: users,
            error: null,
          ),
          onError: (Object e) => state = state.copyWith(
            status: BlockStatus.error,
            error: e.toString(),
          ),
        );
    return const BlockState(status: BlockStatus.loading);
  }

  Future<void> block(String targetUid, {String? displayName}) async {
    final ownerUid = ref.read(authNotifierProvider).user?.uid;
    if (ownerUid == null) return;
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await ref
          .read(_blockUserProvider)
          .call(ownerUid, targetUid, displayName: displayName);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }

  Future<void> unblock(String targetUid) async {
    final ownerUid = ref.read(authNotifierProvider).user?.uid;
    if (ownerUid == null) return;
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await ref.read(_unblockUserProvider).call(ownerUid, targetUid);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}
