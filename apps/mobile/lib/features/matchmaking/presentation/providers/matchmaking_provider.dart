import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/datasources/matchmaking_datasource.dart';
import '../../data/repositories/matchmaking_repository_impl.dart';
import '../../domain/entities/matchmaking_status.dart';
import '../../domain/entities/room.dart';
import '../../domain/repositories/matchmaking_repository.dart';
import '../../domain/usecases/cancel_1v1_pool.dart';
import '../../domain/usecases/create_custom_room.dart';
import '../../domain/usecases/join_1v1_pool.dart';
import '../../domain/usecases/join_group_room.dart';
import '../../domain/usecases/join_room_by_id.dart';
import '../../domain/usecases/leave_room.dart';
import '../../domain/usecases/set_room_lock.dart';
import '../../domain/usecases/watch_1v1_match.dart';
import '../../domain/usecases/watch_room.dart';

// ── DI chain ──────────────────────────────────────────────────────────────────

final _matchmakingDatasourceProvider = Provider<MatchmakingDatasource>(
  (ref) => MatchmakingDatasourceImpl(
    FirebaseFirestore.instance,
    FirebaseFunctions.instanceFor(region: 'us-central1'),
    FirebaseDatabase.instance,
    FirebaseAuth.instance,
  ),
);

final _matchmakingRepositoryProvider = Provider<MatchmakingRepository>(
  (ref) => MatchmakingRepositoryImpl(ref.watch(_matchmakingDatasourceProvider)),
);

final _joinGroupRoomProvider = Provider<JoinGroupRoom>(
  (ref) => JoinGroupRoom(ref.watch(_matchmakingRepositoryProvider)),
);

final _createCustomRoomProvider = Provider<CreateCustomRoom>(
  (ref) => CreateCustomRoom(ref.watch(_matchmakingRepositoryProvider)),
);

final _joinRoomByIdProvider = Provider<JoinRoomById>(
  (ref) => JoinRoomById(ref.watch(_matchmakingRepositoryProvider)),
);

final _leaveRoomProvider = Provider<LeaveRoom>(
  (ref) => LeaveRoom(ref.watch(_matchmakingRepositoryProvider)),
);

final _join1v1PoolProvider = Provider<Join1v1Pool>(
  (ref) => Join1v1Pool(ref.watch(_matchmakingRepositoryProvider)),
);

final _cancel1v1PoolProvider = Provider<Cancel1v1Pool>(
  (ref) => Cancel1v1Pool(ref.watch(_matchmakingRepositoryProvider)),
);

final _setRoomLockProvider = Provider<SetRoomLock>(
  (ref) => SetRoomLock(ref.watch(_matchmakingRepositoryProvider)),
);

final _watchRoomProvider = Provider<WatchRoom>(
  (ref) => WatchRoom(ref.watch(_matchmakingRepositoryProvider)),
);

final _watch1v1MatchProvider = Provider<Watch1v1Match>(
  (ref) => Watch1v1Match(ref.watch(_matchmakingRepositoryProvider)),
);

// ── Public notifier provider ──────────────────────────────────────────────────

final matchmakingNotifierProvider =
    NotifierProvider<MatchmakingNotifier, MatchmakingState>(
      MatchmakingNotifier.new,
    );

// ── State ─────────────────────────────────────────────────────────────────────

const _sentinel = Object();

class MatchmakingState {
  final MatchmakingStatus status;
  final String? roomId;
  final bool isNewRoom;
  final Room? currentRoom;
  final String? error;
  final String interestText;
  final String? backgroundTheme;

  const MatchmakingState({
    this.status = MatchmakingStatus.idle,
    this.roomId,
    this.isNewRoom = false,
    this.currentRoom,
    this.error,
    this.interestText = '',
    this.backgroundTheme,
  });

  MatchmakingState copyWith({
    MatchmakingStatus? status,
    Object? roomId = _sentinel,
    bool? isNewRoom,
    Object? currentRoom = _sentinel,
    Object? error = _sentinel,
    String? interestText,
    Object? backgroundTheme = _sentinel,
  }) => MatchmakingState(
    status: status ?? this.status,
    roomId: roomId == _sentinel ? this.roomId : roomId as String?,
    isNewRoom: isNewRoom ?? this.isNewRoom,
    currentRoom: currentRoom == _sentinel
        ? this.currentRoom
        : currentRoom as Room?,
    error: error == _sentinel ? this.error : error as String?,
    interestText: interestText ?? this.interestText,
    backgroundTheme: backgroundTheme == _sentinel
        ? this.backgroundTheme
        : backgroundTheme as String?,
  );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class MatchmakingNotifier extends Notifier<MatchmakingState> {
  StreamSubscription<Room?>? _roomSub;
  StreamSubscription<String?>? _matchSub;
  // The most recent room ID we occupied. Persists across state resets so that
  // _subscribeToMatch can skip any stale 'matched' pool entry that still points
  // at that room — Firestore's local cache delivers it before the server write
  // from the CF propagates. Cleared once a genuinely new match is processed.
  String? _lastKnownRoomId;

  static const _kInterestTextKey = 'matchmaking_interest_text';

  @override
  MatchmakingState build() {
    ref.onDispose(_cancelSubscriptions);
    return const MatchmakingState();
  }

  void setBackgroundTheme(String? theme) {
    state = state.copyWith(backgroundTheme: theme);
  }

  void setInterestText(String text) {
    state = state.copyWith(interestText: text);
    SharedPreferences.getInstance()
        .then((prefs) => prefs.setString(_kInterestTextKey, text))
        .catchError((_) => false);
  }

  Future<void> loadSavedInterestText() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kInterestTextKey);
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(interestText: saved);
    }
  }

  Future<void> joinGroupRoom() async {
    if (state.status == MatchmakingStatus.searching) return;
    state = state.copyWith(
      status: MatchmakingStatus.searching,
      error: null,
      roomId: null,
    );
    try {
      final interest = state.interestText.isNotEmpty
          ? state.interestText
          : null;
      final result = await ref.read(_joinGroupRoomProvider)(
        interestText: interest,
        backgroundTheme: state.backgroundTheme,
      );
      state = state.copyWith(
        status: MatchmakingStatus.matched,
        roomId: result.roomId,
        isNewRoom: result.isNewRoom,
        error: null,
      );
      _subscribeToRoom(result.roomId);
    } catch (e) {
      state = state.copyWith(
        status: MatchmakingStatus.error,
        error: _message(e),
      );
    }
  }

  Future<void> createCustomRoom() async {
    if (state.status == MatchmakingStatus.creating ||
        state.status == MatchmakingStatus.matched ||
        state.status == MatchmakingStatus.searching ||
        state.status == MatchmakingStatus.waiting1v1) {
      return;
    }
    state = state.copyWith(
      status: MatchmakingStatus.creating,
      error: null,
      roomId: null,
    );
    try {
      final roomId = await ref
          .read(_createCustomRoomProvider)
          .call(backgroundTheme: state.backgroundTheme);
      state = state.copyWith(
        status: MatchmakingStatus.matched,
        roomId: roomId,
        isNewRoom: false,
        error: null,
      );
      _subscribeToRoom(roomId);
    } catch (e) {
      state = state.copyWith(
        status: MatchmakingStatus.error,
        error: _message(e),
      );
    }
  }

  Future<void> joinRoomById(String roomId) async {
    if (state.status == MatchmakingStatus.matched ||
        state.status == MatchmakingStatus.searching ||
        state.status == MatchmakingStatus.creating ||
        state.status == MatchmakingStatus.waiting1v1) {
      return;
    }
    state = state.copyWith(
      status: MatchmakingStatus.searching,
      error: null,
      roomId: null,
    );
    try {
      final result = await ref.read(_joinRoomByIdProvider)(roomId);
      state = state.copyWith(
        status: MatchmakingStatus.matched,
        roomId: result.roomId,
        isNewRoom: false,
        error: null,
      );
      _subscribeToRoom(result.roomId);
    } catch (e) {
      state = state.copyWith(
        status: MatchmakingStatus.error,
        error: _message(e),
      );
    }
  }

  Future<void> leaveRoom() async {
    final roomId = state.roomId;
    if (roomId == null) return;
    _lastKnownRoomId =
        roomId; // preserve so join1v1Pool can skip stale pool entry
    _cancelSubscriptions();
    try {
      await ref.read(_leaveRoomProvider)(roomId);
    } catch (e) {
      final msg = _message(e);
      // Room already gone — treat as a successful leave.
      if (msg.contains('not found') || msg.contains('not-found')) {
        state = _idleState();
        return;
      }
      state = state.copyWith(error: msg);
      return;
    }
    state = _idleState();
  }

  Future<void> join1v1Pool() async {
    if (state.status == MatchmakingStatus.waiting1v1 ||
        state.status == MatchmakingStatus.matched ||
        state.status == MatchmakingStatus.searching ||
        state.status == MatchmakingStatus.creating) {
      return;
    }
    state = state.copyWith(
      status: MatchmakingStatus.waiting1v1,
      error: null,
      roomId: null,
    );
    try {
      final interest = state.interestText.isNotEmpty
          ? state.interestText
          : null;
      await ref
          .read(_join1v1PoolProvider)
          .call(interestText: interest, backgroundTheme: state.backgroundTheme);
      final uid = ref.read(_matchmakingDatasourceProvider).getCurrentUserId();
      if (uid == null) throw Exception('Not signed in.');
      // Pass _lastKnownRoomId so the stream skips any stale 'matched' entry
      // the Firestore cache delivers before the CF's reset propagates.
      final skipRoom = _lastKnownRoomId;
      _lastKnownRoomId = null;
      _subscribeToMatch(uid, skipRoomId: skipRoom);
    } catch (e) {
      state = state.copyWith(
        status: MatchmakingStatus.error,
        error: _message(e),
      );
    }
  }

  Future<void> cancelSearch() async {
    if (state.roomId != null) {
      _lastKnownRoomId = state.roomId;
    }
    _cancelSubscriptions();
    if (state.status == MatchmakingStatus.waiting1v1) {
      await ref.read(_cancel1v1PoolProvider)().catchError((_) => false);
    } else if (state.roomId != null) {
      await ref
          .read(_leaveRoomProvider)(state.roomId!)
          .catchError((_) async {});
    }
    state = _idleState();
  }

  Future<void> setRoomLock({required bool isLocked}) async {
    final roomId = state.roomId;
    if (roomId == null) return;
    try {
      await ref.read(_setRoomLockProvider)(roomId: roomId, isLocked: isLocked);
    } catch (e) {
      state = state.copyWith(error: _message(e));
    }
  }

  // Returns an idle state that preserves interestText and backgroundTheme.
  MatchmakingState _idleState() => MatchmakingState(
    interestText: state.interestText,
    backgroundTheme: state.backgroundTheme,
  );

  void _subscribeToRoom(String roomId) {
    _roomSub?.cancel();
    _roomSub = ref
        .read(_watchRoomProvider)(roomId)
        .listen(
          (room) {
            if (room == null) {
              // Room document vanished while we were matched — go idle.
              if (state.status == MatchmakingStatus.matched) {
                _lastKnownRoomId = state.roomId;
                _cancelSubscriptions();
                state = _idleState();
              } else {
                state = state.copyWith(currentRoom: null);
              }
              return;
            }
            // Room expired (tombstone) — transition to idle.
            if (room.status == RoomStatus.expired) {
              _lastKnownRoomId = state.roomId;
              _cancelSubscriptions();
              state = state.copyWith(
                status: MatchmakingStatus.idle,
                roomId: null,
                currentRoom: null,
                error: null,
              );
              return;
            }
            // 1v1 partner left — backend sets room to padding (30-second window)
            // and re-queues us. Re-subscribe to the match stream for a new partner.
            if (state.status == MatchmakingStatus.matched &&
                room.mode == RoomMode.oneToOne &&
                room.status == RoomStatus.padding) {
              _requeue1v1();
              return;
            }
            state = state.copyWith(currentRoom: room);
          },
          onError: (Object e) {
            // If we're no longer matched (user left voluntarily), this is a
            // late permission-denied from the stream's async cancel — ignore it.
            if (state.status != MatchmakingStatus.matched) return;
            _lastKnownRoomId = state.roomId;
            _cancelSubscriptions();
            final isPermissionDenied =
                (e is FirebaseException && e.code == 'permission-denied') ||
                e.toString().contains('permission-denied');
            state = state.copyWith(
              status: MatchmakingStatus.error,
              error: isPermissionDenied
                  ? 'Room access lost. Please try again.'
                  : 'Connection error. Please try again.',
              roomId: null,
              currentRoom: null,
            );
          },
        );
  }

  void _requeue1v1() {
    _cancelSubscriptions();
    final uid = ref.read(_matchmakingDatasourceProvider).getCurrentUserId();
    if (uid == null) {
      state = _idleState();
      return;
    }
    // Capture the old room ID before clearing state so _subscribeToMatch can
    // skip any stale 'matched' pool entry that still points at the old room.
    // The backend updates waiting_pool AFTER updating the room document, so
    // there is a brief window where the pool doc still shows the old roomId.
    final previousRoomId = state.roomId;
    _lastKnownRoomId =
        previousRoomId; // preserve in case user manually re-joins after cancel
    state = state.copyWith(
      status: MatchmakingStatus.waiting1v1,
      roomId: null,
      currentRoom: null,
      error: 'Partner left — searching for new match…',
      isNewRoom: false,
    );
    _subscribeToMatch(uid, skipRoomId: previousRoomId);
  }

  void _subscribeToMatch(String uid, {String? skipRoomId}) {
    _matchSub?.cancel();
    _matchSub = ref.read(_watch1v1MatchProvider)(uid).listen(
      (roomId) {
        if (roomId == null) return;
        // Skip the old room — the pool entry hasn't been updated yet by the
        // backend. Once it flips to 'waiting' the stream emits null, and the
        // next real match will emit a different roomId.
        if (roomId == skipRoomId) return;
        _matchSub?.cancel();
        _matchSub = null;
        // Register onDisconnect for the 1v1 room — CF writes RTDB entries
        // server-side, so the client must separately set up disconnect cleanup.
        ref
            .read(_matchmakingDatasourceProvider)
            .registerRoomPresence(roomId)
            .catchError((_) {});
        _subscribeToRoom(roomId);
        state = state.copyWith(
          status: MatchmakingStatus.matched,
          roomId: roomId,
          isNewRoom: false,
          error: null,
        );
      },
      onError: (Object e) => state = state.copyWith(
        status: MatchmakingStatus.error,
        error: _message(e),
      ),
    );
  }

  void _cancelSubscriptions() {
    _roomSub?.cancel();
    _matchSub?.cancel();
    _roomSub = null;
    _matchSub = null;
  }

  static String _message(Object e) {
    final s = e.toString().replaceFirst('Exception: ', '');
    if (s.contains('not-found') || s.contains('not found')) {
      return 'Room not found. Check the ID and try again.';
    }
    if (s.contains('has expired') || s.contains('no longer available')) {
      return 'This room is no longer available.';
    }
    if (s.contains('is locked')) return 'This room is locked.';
    if (s.contains('Room is full')) return 'This room is full.';
    if (s.contains('permission-denied')) {
      return 'Not authorized to join this room.';
    }
    return s;
  }
}
