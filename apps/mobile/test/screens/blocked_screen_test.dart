import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/block/domain/entities/blocked_user.dart';
import 'package:mobile/features/block/presentation/providers/block_provider.dart';
import 'package:mobile/screens/blocked_screen.dart';

class _FakeBlockNotifier extends BlockNotifier {
  final BlockState _initial;
  int unblockCallCount = 0;

  _FakeBlockNotifier({BlockState initial = const BlockState()})
    : _initial = initial;

  @override
  BlockState build() => _initial;

  @override
  Future<void> unblock(String targetUid) async {
    unblockCallCount++;
  }

  @override
  Future<void> block(String targetUid, {String? displayName}) async {}
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

Widget _buildScreen({
  required _FakeBlockNotifier blockFake,
  _FakeAuthNotifier? authFake,
}) {
  return ProviderScope(
    overrides: [
      blockNotifierProvider.overrideWith(() => blockFake),
      authNotifierProvider.overrideWith(
        () =>
            authFake ??
            _FakeAuthNotifier(
              initial: const AuthState(
                status: AuthStatus.authenticated,
                user: AuthUser(uid: 'owner-1'),
              ),
            ),
      ),
    ],
    child: const MaterialApp(home: BlockedScreen()),
  );
}

final _ts = DateTime(2024, 1, 15);

BlockedUser _makeUser(String uid, {String? displayName}) =>
    BlockedUser(uid: uid, displayName: displayName, blockedAt: _ts);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BlockedScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_buildScreen(blockFake: _FakeBlockNotifier()));
      await tester.pump();
      expect(find.byType(BlockedScreen), findsOneWidget);
    });

    testWidgets('shows Blocked title in header', (tester) async {
      await tester.pumpWidget(_buildScreen(blockFake: _FakeBlockNotifier()));
      await tester.pump();
      expect(find.text('Blocked'), findsOneWidget);
    });

    testWidgets('shows blocked user count', (tester) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-1'), _makeUser('uid-2')],
        ),
      );
      await tester.pumpWidget(_buildScreen(blockFake: blockFake));
      await tester.pump();
      expect(find.text('2/5'), findsOneWidget);
    });

    testWidgets('shows an Unblock button for each blocked user', (
      tester,
    ) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-1'), _makeUser('uid-2')],
        ),
      );
      await tester.pumpWidget(_buildScreen(blockFake: blockFake));
      await tester.pump();
      expect(find.text('Unblock'), findsNWidgets(2));
    });

    testWidgets('shows the blocked users list', (tester) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-1'), _makeUser('uid-2')],
        ),
      );
      await tester.pumpWidget(_buildScreen(blockFake: blockFake));
      await tester.pump();
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('tapping Unblock shows confirmation dialog', (tester) async {
      final blockFake = _FakeBlockNotifier(
        initial: BlockState(
          status: BlockStatus.loaded,
          blockedUsers: [_makeUser('uid-1')],
        ),
      );
      await tester.pumpWidget(_buildScreen(blockFake: blockFake));
      await tester.pump();
      await tester.tap(find.text('Unblock').first);
      await tester.pumpAndSettle();
      // dialog title uses Friend.displayName which falls back to uid (username)
      expect(find.text('Unblock "uid-1"'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final blockFake = _FakeBlockNotifier(
            initial: BlockState(
              status: BlockStatus.loaded,
              blockedUsers: [_makeUser('uid-1')],
            ),
          );
          await tester.pumpWidget(_buildScreen(blockFake: blockFake));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
          expect(find.bySemanticsLabel('View user profile'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
