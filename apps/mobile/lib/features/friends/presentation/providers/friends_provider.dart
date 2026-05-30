import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/friends_datasource.dart';
import '../../data/repositories/friends_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/friend.dart';
import '../../domain/entities/friend_request.dart';
import '../../domain/entities/friend_room_status.dart';
import '../../domain/repositories/friends_repository.dart';
import '../../domain/usecases/accept_friend_request.dart';
import '../../domain/usecases/decline_friend_request.dart';
import '../../domain/usecases/remove_friend.dart';
import '../../domain/usecases/send_friend_request.dart';
import '../../domain/usecases/watch_all_users.dart';
import '../../domain/usecases/watch_friend_last_message.dart';
import '../../domain/usecases/watch_friend_presence.dart';
import '../../domain/usecases/watch_friend_room.dart';
import '../../domain/usecases/watch_friends.dart';
import '../../domain/usecases/watch_incoming_requests.dart';

final friendsDatasourceProvider = Provider<FriendsDatasource>(
  (ref) => FriendsDatasourceImpl(
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
    FirebaseDatabase.instance,
  ),
);

final friendsRepositoryProvider = Provider<FriendsRepository>(
  (ref) => FriendsRepositoryImpl(ref.watch(friendsDatasourceProvider)),
);

final _watchAllUsersProvider = Provider<WatchAllUsers>(
  (ref) => WatchAllUsers(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendsProvider = Provider<WatchFriends>(
  (ref) => WatchFriends(ref.watch(friendsRepositoryProvider)),
);

final _watchIncomingRequestsProvider = Provider<WatchIncomingRequests>(
  (ref) => WatchIncomingRequests(ref.watch(friendsRepositoryProvider)),
);

final _sendFriendRequestProvider = Provider<SendFriendRequest>(
  (ref) => SendFriendRequest(ref.watch(friendsRepositoryProvider)),
);

final _acceptFriendRequestProvider = Provider<AcceptFriendRequest>(
  (ref) => AcceptFriendRequest(ref.watch(friendsRepositoryProvider)),
);

final _declineFriendRequestProvider = Provider<DeclineFriendRequest>(
  (ref) => DeclineFriendRequest(ref.watch(friendsRepositoryProvider)),
);

final _removeFriendProvider = Provider<RemoveFriend>(
  (ref) => RemoveFriend(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendPresenceProvider = Provider<WatchFriendPresence>(
  (ref) => WatchFriendPresence(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendLastMessageProvider = Provider<WatchFriendLastMessage>(
  (ref) => WatchFriendLastMessage(ref.watch(friendsRepositoryProvider)),
);

final _watchFriendRoomProvider = Provider<WatchFriendRoom>(
  (ref) => WatchFriendRoom(ref.watch(friendsRepositoryProvider)),
);

final friendsNotifierProvider = NotifierProvider<FriendsNotifier, FriendsState>(
  FriendsNotifier.new,
);

const _sentinel = Object();

class FriendsState {
  final List<AppUser> allUsers;
  final List<Friend> friends;
  final List<FriendRequest> incomingRequests;
  final bool isLoading;
  final String? error;
  // keyed by friendUid
  final Map<String, bool> presenceMap;
  // keyed by chatRoomId
  final Map<String, String> lastMessageMap;
  // keyed by friendUid
  final Map<String, FriendRoomStatus?> roomMap;

  const FriendsState({
    this.allUsers = const [],
    this.friends = const [],
    this.incomingRequests = const [],
    this.isLoading = false,
    this.error,
    this.presenceMap = const {},
    this.lastMessageMap = const {},
    this.roomMap = const {},
  });

  FriendsState copyWith({
    List<AppUser>? allUsers,
    List<Friend>? friends,
    List<FriendRequest>? incomingRequests,
    bool? isLoading,
    Object? error = _sentinel,
    Map<String, bool>? presenceMap,
    Map<String, String>? lastMessageMap,
    Map<String, FriendRoomStatus?>? roomMap,
  }) => FriendsState(
    allUsers: allUsers ?? this.allUsers,
    friends: friends ?? this.friends,
    incomingRequests: incomingRequests ?? this.incomingRequests,
    isLoading: isLoading ?? this.isLoading,
    error: error == _sentinel ? this.error : error as String?,
    presenceMap: presenceMap ?? this.presenceMap,
    lastMessageMap: lastMessageMap ?? this.lastMessageMap,
    roomMap: roomMap ?? this.roomMap,
  );
}

class FriendsNotifier extends Notifier<FriendsState> {
  StreamSubscription<List<Friend>>? _friendsSub;
  StreamSubscription<List<FriendRequest>>? _requestsSub;
  StreamSubscription<List<AppUser>>? _usersSub;

  final Map<String, StreamSubscription<bool>> _presenceSubs = {};
  final Map<String, StreamSubscription<String>> _lastMessageSubs = {};
  final Map<String, StreamSubscription<FriendRoomStatus?>> _roomSubs = {};

  @override
  FriendsState build() {
    ref.onDispose(() {
      _friendsSub?.cancel();
      _requestsSub?.cancel();
      _usersSub?.cancel();
      for (final sub in _presenceSubs.values) {
        sub.cancel();
      }
      for (final sub in _lastMessageSubs.values) {
        sub.cancel();
      }
      for (final sub in _roomSubs.values) {
        sub.cancel();
      }
    });

    _friendsSub = ref.read(_watchFriendsProvider)().listen(
      (friends) {
        state = state.copyWith(friends: friends);
        _updateEnrichmentSubscriptions(friends);
      },
      onError: (Object e) => state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      ),
    );

    _requestsSub = ref
        .read(_watchIncomingRequestsProvider)()
        .listen(
          (requests) => state = state.copyWith(incomingRequests: requests),
          onError: (Object e) => state = state.copyWith(
            error: e.toString().replaceFirst('Exception: ', ''),
          ),
        );

    _usersSub = ref
        .read(_watchAllUsersProvider)()
        .listen(
          (users) => state = state.copyWith(allUsers: users),
          onError: (Object e) => state = state.copyWith(
            error: e.toString().replaceFirst('Exception: ', ''),
          ),
        );

    return const FriendsState();
  }

  void _updateEnrichmentSubscriptions(List<Friend> friends) {
    final currentUids = {for (final f in friends) f.friendUid};
    final currentRoomIds = {for (final f in friends) f.chatRoomId};

    final removedUids = _presenceSubs.keys.toSet().difference(currentUids);
    for (final uid in removedUids) {
      _presenceSubs.remove(uid)?.cancel();
      _roomSubs.remove(uid)?.cancel();
    }

    final removedRoomIds = _lastMessageSubs.keys.toSet().difference(
      currentRoomIds,
    );
    for (final roomId in removedRoomIds) {
      _lastMessageSubs.remove(roomId)?.cancel();
    }

    if (removedUids.isNotEmpty || removedRoomIds.isNotEmpty) {
      final newPresence = Map<String, bool>.from(state.presenceMap)
        ..removeWhere((k, _) => removedUids.contains(k));
      final newRoom = Map<String, FriendRoomStatus?>.from(state.roomMap)
        ..removeWhere((k, _) => removedUids.contains(k));
      final newLastMsg = Map<String, String>.from(state.lastMessageMap)
        ..removeWhere((k, _) => removedRoomIds.contains(k));
      state = state.copyWith(
        presenceMap: newPresence,
        roomMap: newRoom,
        lastMessageMap: newLastMsg,
      );
    }

    for (final f in friends) {
      if (!_presenceSubs.containsKey(f.friendUid)) {
        _presenceSubs[f.friendUid] = ref
            .read(_watchFriendPresenceProvider)(f.friendUid)
            .listen((isOnline) {
              state = state.copyWith(
                presenceMap: Map<String, bool>.from(state.presenceMap)
                  ..[f.friendUid] = isOnline,
              );
            }, onError: (_) {});
      }

      if (!_lastMessageSubs.containsKey(f.chatRoomId)) {
        _lastMessageSubs[f.chatRoomId] = ref
            .read(_watchFriendLastMessageProvider)(f.chatRoomId)
            .listen((msg) {
              state = state.copyWith(
                lastMessageMap: Map<String, String>.from(state.lastMessageMap)
                  ..[f.chatRoomId] = msg,
              );
            }, onError: (_) {});
      }

      if (!_roomSubs.containsKey(f.friendUid)) {
        _roomSubs[f.friendUid] = ref
            .read(_watchFriendRoomProvider)(f.friendUid)
            .listen((room) {
              state = state.copyWith(
                roomMap: Map<String, FriendRoomStatus?>.from(state.roomMap)
                  ..[f.friendUid] = room,
              );
            }, onError: (_) {});
      }
    }
  }

  Future<void> sendFriendRequest(AppUser toUser) async {
    if (state.isLoading) return;
    final myDisplayName =
        ref.read(authNotifierProvider).user?.displayName ?? 'Anonymous';
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(_sendFriendRequestProvider)(
        toUid: toUser.uid,
        toDisplayName: toUser.displayName,
        fromDisplayName: myDisplayName,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> acceptRequest(FriendRequest request) async {
    if (state.isLoading) return;
    final myDisplayName =
        ref.read(authNotifierProvider).user?.displayName ?? 'Anonymous';
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(_acceptFriendRequestProvider)(
        requestId: request.id,
        fromUid: request.fromUid,
        fromDisplayName: request.fromDisplayName,
        myDisplayName: myDisplayName,
      );
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> declineRequest(String requestId) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(_declineFriendRequestProvider)(requestId: requestId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> removeFriend(String friendshipId) async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(_removeFriendProvider)(friendshipId: friendshipId);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearError() => state = state.copyWith(error: null);
}
