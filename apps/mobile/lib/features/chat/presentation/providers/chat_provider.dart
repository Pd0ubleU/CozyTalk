import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/chat_datasource.dart';
import '../../data/repositories/chat_repository_impl.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/session_status.dart';
import '../../domain/entities/typing_user.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/end_session.dart';
import '../../domain/usecases/send_message.dart';
import '../../domain/usecases/set_typing.dart';
import '../../domain/usecases/watch_messages.dart';
import '../../domain/usecases/watch_partner_typing.dart';
import '../../../word_filter/presentation/providers/word_filter_provider.dart';

final _chatDatasourceProvider = Provider<ChatDatasource>(
  (ref) => ChatDatasourceImpl(
    FirebaseFirestore.instance,
    FirebaseDatabase.instance,
    FirebaseFunctions.instance,
    FirebaseAuth.instance,
  ),
);

final _chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepositoryImpl(ref.watch(_chatDatasourceProvider)),
);

final _watchMessagesProvider = Provider<WatchMessages>(
  (ref) => WatchMessages(ref.watch(_chatRepositoryProvider)),
);

final _watchTypingUsersProvider = Provider<WatchTypingUsers>(
  (ref) => WatchTypingUsers(ref.watch(_chatRepositoryProvider)),
);

final _sendMessageProvider = Provider<SendMessage>(
  (ref) => SendMessage(ref.watch(_chatRepositoryProvider)),
);

final _setTypingProvider = Provider<SetTyping>(
  (ref) => SetTyping(ref.watch(_chatRepositoryProvider)),
);

final _endSessionProvider = Provider<EndSession>(
  (ref) => EndSession(ref.watch(_chatRepositoryProvider)),
);

final chatNotifierProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

const _sentinel = Object();

class ChatState {
  final SessionStatus status;
  final String? sessionId;
  final String? currentUserId;
  final String? currentUserDisplayName;
  final String? currentUserPhotoUrl;
  final List<ChatMessage> messages;
  final List<TypingUser> typingUsers;
  final bool isSending;
  final String? error;

  const ChatState({
    this.status = SessionStatus.idle,
    this.sessionId,
    this.currentUserId,
    this.currentUserDisplayName,
    this.currentUserPhotoUrl,
    this.messages = const [],
    this.typingUsers = const [],
    this.isSending = false,
    this.error,
  });

  ChatState copyWith({
    SessionStatus? status,
    Object? sessionId = _sentinel,
    Object? currentUserId = _sentinel,
    Object? currentUserDisplayName = _sentinel,
    Object? currentUserPhotoUrl = _sentinel,
    List<ChatMessage>? messages,
    List<TypingUser>? typingUsers,
    bool? isSending,
    Object? error = _sentinel,
  }) => ChatState(
    status: status ?? this.status,
    sessionId: sessionId == _sentinel ? this.sessionId : sessionId as String?,
    currentUserId: currentUserId == _sentinel
        ? this.currentUserId
        : currentUserId as String?,
    currentUserDisplayName: currentUserDisplayName == _sentinel
        ? this.currentUserDisplayName
        : currentUserDisplayName as String?,
    currentUserPhotoUrl: currentUserPhotoUrl == _sentinel
        ? this.currentUserPhotoUrl
        : currentUserPhotoUrl as String?,
    messages: messages ?? this.messages,
    typingUsers: typingUsers ?? this.typingUsers,
    isSending: isSending ?? this.isSending,
    error: error == _sentinel ? this.error : error as String?,
  );
}

class ChatNotifier extends Notifier<ChatState> {
  StreamSubscription<List<ChatMessage>>? _messagesSub;
  StreamSubscription<List<TypingUser>>? _typingSub;

  @override
  ChatState build() => const ChatState();

  void enterSession({
    required String sessionId,
    required String currentUserId,
    String? currentUserDisplayName,
    String? currentUserPhotoUrl,
  }) {
    _cancelSubscriptions();
    state = ChatState(
      status: SessionStatus.chatting,
      sessionId: sessionId,
      currentUserId: currentUserId,
      currentUserDisplayName: currentUserDisplayName,
      currentUserPhotoUrl: currentUserPhotoUrl,
    );

    _joinProtoThenSubscribe(sessionId, currentUserId);
  }

  Future<void> _joinProtoThenSubscribe(String sessionId, String uid) async {
    try {
      final displayName = await ref
          .read(_chatDatasourceProvider)
          .joinProtoSession(sessionId: sessionId, uid: uid);
      state = state.copyWith(currentUserDisplayName: displayName);
      _startSubscriptions(sessionId);
    } catch (e) {
      state = state.copyWith(
        status: SessionStatus.disconnected,
        error: e.toString(),
      );
    }
  }

  void _startSubscriptions(String sessionId) {
    _messagesSub = ref
        .read(_watchMessagesProvider)(sessionId)
        .listen(
          (messages) => state = state.copyWith(messages: messages),
          onError: (Object e) {
            final msg = e.toString();
            if (msg.contains('permission-denied') ||
                msg.contains('PERMISSION_DENIED')) {
              state = state.copyWith(
                status: SessionStatus.disconnected,
                error: 'Room is no longer available.',
              );
              _cancelSubscriptions();
            } else {
              state = state.copyWith(error: msg);
            }
          },
        );

    _typingSub = ref
        .read(_watchTypingUsersProvider)(sessionId)
        .listen(
          (users) {
            final others = users
                .where((u) => u.uid != state.currentUserId)
                .toList();
            state = state.copyWith(typingUsers: others);
          },
          onError: (Object _) {
            // permission-denied fires when the session ends and rules revoke access.
            // Cancel silently — the session is already over.
            _typingSub?.cancel();
            _typingSub = null;
          },
        );
  }

  Future<void> sendMessage(String text) async {
    final sessionId = state.sessionId;
    if (sessionId == null || state.isSending) return;
    state = state.copyWith(isSending: true, error: null);
    try {
      var textToSend = text;
      try {
        textToSend = await ref.read(censorTextProvider).call(text);
      } catch (e) {
        debugPrint('censorText failed, sending original: $e');
      }
      await ref.read(_sendMessageProvider)(
        sessionId: sessionId,
        text: textToSend,
      );
      state = state.copyWith(isSending: false);
    } catch (e) {
      state = state.copyWith(isSending: false, error: e.toString());
    }
  }

  Future<void> setTyping(bool isTyping) async {
    final sessionId = state.sessionId;
    final uid = state.currentUserId;
    if (sessionId == null || uid == null) return;
    try {
      await ref.read(_setTypingProvider)(
        sessionId: sessionId,
        isTyping: isTyping,
        currentUid: uid,
        displayName: state.currentUserDisplayName ?? 'Anonymous',
        photoUrl: state.currentUserPhotoUrl,
      );
    } catch (_) {}
  }

  Future<void> endSession() async {
    final sessionId = state.sessionId;
    if (sessionId == null) return;
    _cancelSubscriptions();
    try {
      await ref.read(_endSessionProvider)(sessionId);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return;
    }
    state = state.copyWith(
      status: SessionStatus.disconnected,
      sessionId: null,
      messages: [],
      typingUsers: [],
    );
  }

  void forceDisconnect() {
    if (state.status == SessionStatus.disconnected) return;
    _cancelSubscriptions();
    state = state.copyWith(
      status: SessionStatus.disconnected,
      sessionId: null,
      messages: [],
      typingUsers: [],
    );
  }

  void _cancelSubscriptions() {
    _messagesSub?.cancel();
    _typingSub?.cancel();
    _messagesSub = null;
    _typingSub = null;
  }
}
