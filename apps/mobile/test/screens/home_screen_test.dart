import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/features/friends/domain/entities/friend_request.dart';
import 'package:mobile/features/friends/presentation/providers/friends_provider.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';
import '../shared/fake_network_info.dart';

// ── Fakes ─────────────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithGoogle() async {}
}

class _FakeProfileNotifier extends ProfileNotifier {
  final ProfileState _initial;
  int loadCount = 0;
  int updateThoughtsCount = 0;
  String? lastUid;
  String? lastThoughts;

  _FakeProfileNotifier({ProfileState initial = const ProfileState()})
    : _initial = initial;

  @override
  ProfileState build() => _initial;

  @override
  Future<void> load(String uid) async {
    loadCount++;
    lastUid = uid;
  }

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {}

  @override
  Future<void> updateInterest(String uid, String interest) async {}

  @override
  Future<void> updateThoughts(String uid, String thoughts) async {
    updateThoughtsCount++;
    lastUid = uid;
    lastThoughts = thoughts;
  }
}

class _FakeFriendsNotifier extends FriendsNotifier {
  final FriendsState _initial;
  _FakeFriendsNotifier({FriendsState initial = const FriendsState()})
    : _initial = initial;

  @override
  FriendsState build() => _initial;
}

class _FakeAvatarDecorationNotifier extends AvatarDecorationNotifier {
  final AvatarDecorationState _initial;
  int loadCount = 0;
  int updateMoodCount = 0;
  int updateHatCount = 0;

  _FakeAvatarDecorationNotifier({
    AvatarDecorationState initial = const AvatarDecorationState(),
  }) : _initial = initial;

  @override
  AvatarDecorationState build() => _initial;

  @override
  Future<void> load(String uid) async => loadCount++;

  @override
  Future<void> updateMood(String uid, String? moodKey) async =>
      updateMoodCount++;

  @override
  Future<void> updateHat(String uid, String? hatKey) async => updateHatCount++;

  @override
  Future<void> updateDecoration(
    String uid,
    String? hatKey,
    String? moodKey,
  ) async {}

  void triggerError(String msg) {
    state = state.copyWith(status: AvatarDecorationStatus.error, error: msg);
  }
}

// ── Helpers ────────────────────────────────────────────────────────────────────

const _authenticatedAuth = AuthState(
  status: AuthStatus.authenticated,
  user: AuthUser(uid: 'test-uid'),
);

Widget _buildScreen(
  _FakeProfileNotifier profileFake,
  _FakeAvatarDecorationNotifier avatarFake, {
  AuthState auth = _authenticatedAuth,
  FriendsState friends = const FriendsState(),
  NetworkInfo? networkInfo,
}) {
  return ProviderScope(
    overrides: [
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(initial: auth)),
      profileNotifierProvider.overrideWith(() => profileFake),
      avatarDecorationNotifierProvider.overrideWith(() => avatarFake),
      friendsNotifierProvider.overrideWith(
        () => _FakeFriendsNotifier(initial: friends),
      ),
      if (networkInfo != null)
        networkInfoProvider.overrideWithValue(networkInfo),
    ],
    child: const MaterialApp(home: HomeScreen()),
  );
}

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('HomeScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        _buildScreen(_FakeProfileNotifier(), _FakeAvatarDecorationNotifier()),
      );
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('displays username from profileNotifierProvider', (
      tester,
    ) async {
      final profile = _FakeProfileNotifier(
        initial: ProfileState(
          profile: const ProfileUser(uid: 'test-uid', displayName: 'Alice'),
        ),
      );
      await tester.pumpWidget(
        _buildScreen(profile, _FakeAvatarDecorationNotifier()),
      );

      expect(find.text('Hello, Alice!'), findsOneWidget);
    });

    testWidgets('displays thoughts from profileNotifierProvider', (
      tester,
    ) async {
      final profile = _FakeProfileNotifier(
        initial: ProfileState(
          profile: const ProfileUser(
            uid: 'test-uid',
            thoughts: 'Feeling great today',
          ),
        ),
      );
      await tester.pumpWidget(
        _buildScreen(profile, _FakeAvatarDecorationNotifier()),
      );

      expect(find.text('Feeling great today'), findsOneWidget);
    });

    testWidgets('calls load on profile and avatar notifiers on mount', (
      tester,
    ) async {
      final profile = _FakeProfileNotifier();
      final avatar = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(_buildScreen(profile, avatar));
      await tester.pump();

      expect(profile.loadCount, 1);
      expect(profile.lastUid, 'test-uid');
      expect(avatar.loadCount, 1);
    });

    testWidgets('does not call load when user is unauthenticated', (
      tester,
    ) async {
      final profile = _FakeProfileNotifier();
      final avatar = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(
        _buildScreen(
          profile,
          avatar,
          auth: const AuthState(status: AuthStatus.unauthenticated),
        ),
      );
      await tester.pump();

      expect(profile.loadCount, 0);
      expect(avatar.loadCount, 0);
    });

    testWidgets('calls updateThoughts when dialog Save is tapped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = _FakeProfileNotifier(
        initial: ProfileState(
          profile: const ProfileUser(uid: 'test-uid', thoughts: 'Old thought'),
        ),
      );
      final avatar = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(_buildScreen(profile, avatar));
      await tester.pump();

      await tester.tap(find.text('Old thought'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'New thought');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(profile.updateThoughtsCount, 1);
      expect(profile.lastThoughts, 'New thought');
      expect(profile.lastUid, 'test-uid');
    });

    testWidgets('shows notification badge when there are incoming requests', (
      tester,
    ) async {
      final request = FriendRequest(
        id: 'r1',
        fromUid: 'uid-a',
        fromDisplayName: 'Alice',
        toUid: 'test-uid',
        toDisplayName: 'Me',
        status: FriendRequestStatus.pending,
        createdAt: DateTime(2025),
      );
      await tester.pumpWidget(
        _buildScreen(
          _FakeProfileNotifier(),
          _FakeAvatarDecorationNotifier(),
          friends: FriendsState(incomingRequests: [request]),
        ),
      );

      final badge = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).shape == BoxShape.circle &&
            (w.decoration as BoxDecoration).color == const Color(0xFFCF5733),
      );
      expect(badge, findsOneWidget);
    });

    testWidgets(
      'hides notification badge when there are no incoming requests',
      (tester) async {
        await tester.pumpWidget(
          _buildScreen(_FakeProfileNotifier(), _FakeAvatarDecorationNotifier()),
        );

        final badge = find.byWidgetPredicate(
          (w) =>
              w is Container &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).shape == BoxShape.circle &&
              (w.decoration as BoxDecoration).color == const Color(0xFFCF5733),
        );
        expect(badge, findsNothing);
      },
    );

    testWidgets('does not call updateThoughts when dialog Cancel is tapped', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final profile = _FakeProfileNotifier(
        initial: ProfileState(
          profile: const ProfileUser(uid: 'test-uid', thoughts: 'Old thought'),
        ),
      );
      final avatar = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(_buildScreen(profile, avatar));
      await tester.pump();

      await tester.tap(find.text('Old thought'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(profile.updateThoughtsCount, 0);
    });

    testWidgets('OfflineChip visible when offline', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProfileNotifier(),
          _FakeAvatarDecorationNotifier(),
          networkInfo: FakeNetworkInfo(isOnline: false),
        ),
      );
      await tester.pump(); // let stream emit
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('OfflineChip not visible when online', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProfileNotifier(),
          _FakeAvatarDecorationNotifier(),
          networkInfo: FakeNetworkInfo(isOnline: true),
        ),
      );
      await tester.pump();
      expect(find.text('Offline'), findsNothing);
    });

    testWidgets('avatar error SnackBar shown when error state is set', (
      tester,
    ) async {
      final avatarFake = _FakeAvatarDecorationNotifier();
      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(initial: _authenticatedAuth),
          ),
          profileNotifierProvider.overrideWith(() => _FakeProfileNotifier()),
          avatarDecorationNotifierProvider.overrideWith(() => avatarFake),
          friendsNotifierProvider.overrideWith(() => _FakeFriendsNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();

      // Trigger a state change from null → error, which fires the ref.listen.
      (container.read(avatarDecorationNotifierProvider.notifier)
              as _FakeAvatarDecorationNotifier)
          .triggerError('test avatar error');
      await tester.pump();

      expect(find.text('test avatar error'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _buildScreen(
              _FakeProfileNotifier(),
              _FakeAvatarDecorationNotifier(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Notifications'), findsOneWidget);
          expect(find.bySemanticsLabel('View profile'), findsOneWidget);
          // _ThoughtBubble is inside a ClipRRect; semantics node is present
          // but excluded from the accessible node tree — assert via widget predicate.
          expect(
            find.byWidgetPredicate(
              (w) =>
                  w is Semantics && w.properties.label == 'Edit thought bubble',
              skipOffstage: false,
            ),
            findsOneWidget,
          );
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
