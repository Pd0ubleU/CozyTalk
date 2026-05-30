import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/screens/profile_edit_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';

class _FakeNetworkInfo implements NetworkInfo {
  final bool _isOnline;
  _FakeNetworkInfo({required bool isOnline}) : _isOnline = isOnline;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(_isOnline);

  @override
  Future<bool> get isConnected async => _isOnline;
}

class _FakeAvatarNotifier extends AvatarNotifier {
  @override
  AvatarState build() => const AvatarState();
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signOut() async {}

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
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInAnonymously() async {}
}

class _FakeProfileNotifier extends ProfileNotifier {
  final ProfileState _initial;
  int loadCount = 0;

  _FakeProfileNotifier({ProfileState initial = const ProfileState()})
    : _initial = initial;

  @override
  ProfileState build() => _initial;

  @override
  Future<void> load(String uid) async => loadCount++;

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {}

  @override
  Future<void> updateInterest(String uid, String interest) async {}
}

Widget _build({
  required AuthNotifier authFake,
  required _FakeProfileNotifier profileFake,
  NetworkInfo? networkInfo,
}) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(() => authFake),
    profileNotifierProvider.overrideWith(() => profileFake),
    avatarProvider.overrideWith(() => _FakeAvatarNotifier()),
    if (networkInfo != null) networkInfoProvider.overrideWithValue(networkInfo),
  ],
  child: const MaterialApp(home: ProfileScreen()),
);

final _authenticatedUser = AuthUser(
  uid: 'uid-1',
  email: 'user@example.com',
  displayName: 'TestUser',
);

final _anonymousUser = AuthUser(uid: 'uid-anon');

void main() {
  group('ProfileScreen (production)', () {
    testWidgets('renders username and interest from profileNotifierProvider', (
      tester,
    ) async {
      final profileFake = _FakeProfileNotifier(
        initial: ProfileState(
          profile: ProfileUser(
            uid: 'uid-1',
            displayName: 'Alice',
            interest: 'Music',
          ),
        ),
      );
      await tester.pumpWidget(
        _build(
          authFake: _FakeAuthNotifier(
            initial: AuthState(
              status: AuthStatus.authenticated,
              user: _authenticatedUser,
            ),
          ),
          profileFake: profileFake,
        ),
      );
      await tester.pump();
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Music'), findsOneWidget);
    });

    testWidgets('shows email card for authenticated user with email', (
      tester,
    ) async {
      await tester.pumpWidget(
        _build(
          authFake: _FakeAuthNotifier(
            initial: AuthState(
              status: AuthStatus.authenticated,
              user: _authenticatedUser,
            ),
          ),
          profileFake: _FakeProfileNotifier(),
        ),
      );
      await tester.pump();
      expect(find.text('user@example.com'), findsOneWidget);
    });

    testWidgets('hides email card for anonymous user', (tester) async {
      await tester.pumpWidget(
        _build(
          authFake: _FakeAuthNotifier(
            initial: AuthState(
              status: AuthStatus.authenticated,
              user: _anonymousUser,
            ),
          ),
          profileFake: _FakeProfileNotifier(),
        ),
      );
      await tester.pump();
      expect(find.text('Email :'), findsNothing);
    });

    testWidgets('calls load on mount when uid is available', (tester) async {
      final profileFake = _FakeProfileNotifier();
      await tester.pumpWidget(
        _build(
          authFake: _FakeAuthNotifier(
            initial: AuthState(
              status: AuthStatus.authenticated,
              user: _authenticatedUser,
            ),
          ),
          profileFake: profileFake,
        ),
      );
      await tester.pump();
      expect(profileFake.loadCount, 1);
    });

    testWidgets('logout button calls signOut', (tester) async {
      int signOutCount = 0;
      final countingAuthFake = _CountingAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: _authenticatedUser,
        ),
        onSignOut: () => signOutCount++,
      );
      await tester.pumpWidget(
        _build(authFake: countingAuthFake, profileFake: _FakeProfileNotifier()),
      );
      await tester.pump();
      await tester.tap(find.text('Log out'));
      await tester.pump();
      expect(signOutCount, 1);
    });

    testWidgets('edit button pushes ProfileEditScreen', (tester) async {
      await tester.pumpWidget(
        _build(
          authFake: _FakeAuthNotifier(
            initial: AuthState(
              status: AuthStatus.authenticated,
              user: _authenticatedUser,
            ),
          ),
          profileFake: _FakeProfileNotifier(),
        ),
      );
      await tester.pump();

      // Non-null onTap GestureDetectors in tree order:
      // 0 = back button, 1 = edit icon, 2 = Blocked card, 3 = Contact us, 4 = Log out
      final editButton = find
          .byWidgetPredicate((w) => w is GestureDetector && w.onTap != null)
          .at(1);
      await tester.tap(editButton);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileEditScreen), findsOneWidget);
    });

    testWidgets('OfflineChip visible when offline', (tester) async {
      await tester.pumpWidget(
        _build(
          authFake: _FakeAuthNotifier(),
          profileFake: _FakeProfileNotifier(),
          networkInfo: _FakeNetworkInfo(isOnline: false),
        ),
      );
      await tester.pump();
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('OfflineChip not visible when online', (tester) async {
      await tester.pumpWidget(
        _build(
          authFake: _FakeAuthNotifier(),
          profileFake: _FakeProfileNotifier(),
          networkInfo: _FakeNetworkInfo(isOnline: true),
        ),
      );
      await tester.pump();
      expect(find.text('Offline'), findsNothing);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _build(
              authFake: _FakeAuthNotifier(
                initial: AuthState(
                  status: AuthStatus.authenticated,
                  user: _authenticatedUser,
                ),
              ),
              profileFake: _FakeProfileNotifier(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
          expect(find.bySemanticsLabel('Edit profile'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}

class _CountingAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  final VoidCallback onSignOut;

  _CountingAuthNotifier({required AuthState initial, required this.onSignOut})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signOut() async => onSignOut();

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
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInAnonymously() async {}
}
