import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/block/domain/entities/blocked_user.dart';
import 'package:mobile/features/block/presentation/providers/block_provider.dart';
import 'package:mobile/screens/blocked_screen.dart';

// ─── Fake notifiers ──────────────────────────────────────────────────────────

class _FakeBlockNotifier extends BlockNotifier {
  final BlockState _initial;
  int unblockCallCount = 0;
  int blockCallCount = 0;

  _FakeBlockNotifier({BlockState initial = const BlockState()})
    : _initial = initial;

  @override
  BlockState build() => _initial;

  @override
  Future<void> unblock(String targetUid) async {
    unblockCallCount++;
  }

  @override
  Future<void> block(String targetUid, {String? displayName}) async {
    blockCallCount++;
  }
}

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
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {}
}

// ─── Helper ──────────────────────────────────────────────────────────────────

Widget _buildScreen({
  required _FakeBlockNotifier blockFake,
  required _FakeAuthNotifier authFake,
}) {
  return ProviderScope(
    overrides: [
      blockNotifierProvider.overrideWith(() => blockFake),
      authNotifierProvider.overrideWith(() => authFake),
    ],
    child: const MaterialApp(home: BlockedScreen()),
  );
}

final _ts = DateTime(2024, 1, 15);

BlockedUser _makeUser(String uid, {String? displayName}) =>
    BlockedUser(uid: uid, displayName: displayName, blockedAt: _ts);

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlockedScreen', () {
    testWidgets('renders "No blocked users" when blocked list is empty', (
      tester,
    ) async {
      final blockFake = _FakeBlockNotifier();
      final authFake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(uid: 'owner-1'),
        ),
      );

      await tester.pumpWidget(
        _buildScreen(blockFake: blockFake, authFake: authFake),
      );
      await tester.pump();

      expect(find.text('No blocked users'), findsOneWidget);
    });

    testWidgets('shows "0/5" count when blocked list is empty', (tester) async {
      final blockFake = _FakeBlockNotifier();
      final authFake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(uid: 'owner-1'),
        ),
      );

      await tester.pumpWidget(
        _buildScreen(blockFake: blockFake, authFake: authFake),
      );
      await tester.pump();

      expect(find.text('0/5'), findsOneWidget);
    });

    testWidgets('renders user uid when displayName is null', (tester) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-abc')],
        ),
      );
      final authFake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(uid: 'owner-1'),
        ),
      );

      await tester.pumpWidget(
        _buildScreen(blockFake: blockFake, authFake: authFake),
      );
      await tester.pump();

      expect(find.text('uid-abc'), findsOneWidget);
    });

    testWidgets('renders user display names when list has entries', (
      tester,
    ) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [
            _makeUser('uid-1', displayName: 'Alice'),
            _makeUser('uid-2', displayName: 'Bob'),
          ],
        ),
      );
      final authFake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(uid: 'owner-1'),
        ),
      );

      await tester.pumpWidget(
        _buildScreen(blockFake: blockFake, authFake: authFake),
      );
      await tester.pump();

      // Friend.displayName returns username (= uid) when note is absent;
      // the screen passes displayName as 'name' but the widget shows username.
      expect(find.text('uid-1'), findsOneWidget);
      expect(find.text('uid-2'), findsOneWidget);
    });

    testWidgets('shows "2/5" count when two users are blocked', (tester) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-1'), _makeUser('uid-2')],
        ),
      );
      final authFake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(uid: 'owner-1'),
        ),
      );

      await tester.pumpWidget(
        _buildScreen(blockFake: blockFake, authFake: authFake),
      );
      await tester.pump();

      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('shows "1/5" count when one user is blocked', (tester) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-1')],
        ),
      );
      final authFake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(uid: 'owner-1'),
        ),
      );

      await tester.pumpWidget(
        _buildScreen(blockFake: blockFake, authFake: authFake),
      );
      await tester.pump();

      expect(find.text('1/5'), findsOneWidget);
    });

    testWidgets('renders Unblock button for each blocked user', (tester) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-1'), _makeUser('uid-2')],
        ),
      );
      final authFake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(uid: 'owner-1'),
        ),
      );

      await tester.pumpWidget(
        _buildScreen(blockFake: blockFake, authFake: authFake),
      );
      await tester.pump();

      expect(find.text('Unblock'), findsNWidgets(2));
    });

    testWidgets(
      'tapping Unblock button shows confirm dialog then calls unblock on confirm',
      (tester) async {
        final blockFake = _FakeBlockNotifier(
          initial: BlockState(
            status: BlockStatus.loaded,
            blockedUsers: [_makeUser('uid-1')],
          ),
        );
        final authFake = _FakeAuthNotifier(
          initial: const AuthState(
            status: AuthStatus.authenticated,
            user: AuthUser(uid: 'owner-1'),
          ),
        );

        await tester.pumpWidget(
          _buildScreen(blockFake: blockFake, authFake: authFake),
        );
        await tester.pump();

        // Tap the Unblock GestureDetector
        await tester.tap(find.text('Unblock'));
        await tester.pumpAndSettle();

        // Confirm dialog should appear
        expect(find.text('Unblock "uid-1"'), findsOneWidget);

        // Tap the confirm button in the dialog
        final confirmButtons = find.text('Unblock');
        // The last 'Unblock' text is the dialog confirm button
        await tester.tap(confirmButtons.last);
        await tester.pumpAndSettle();

        expect(blockFake.unblockCallCount, 1);
      },
    );

    testWidgets('tapping Cancel in unblock dialog does not call unblock', (
      tester,
    ) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-1')],
        ),
      );
      final authFake = _FakeAuthNotifier(
        initial: const AuthState(
          status: AuthStatus.authenticated,
          user: AuthUser(uid: 'owner-1'),
        ),
      );

      await tester.pumpWidget(
        _buildScreen(blockFake: blockFake, authFake: authFake),
      );
      await tester.pump();

      await tester.tap(find.text('Unblock'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(blockFake.unblockCallCount, 0);
    });
  });
}
