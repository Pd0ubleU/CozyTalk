import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/screens/admin_profile_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  int signOutCount = 0;
  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signOut() async => signOutCount++;

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signInWithGoogle() async {}
  @override
  Future<void> signInAnonymously() async {}
}

Widget _build(_FakeAuthNotifier fake, {int resolved = 0, int bans = 0}) =>
    ProviderScope(
      overrides: [authNotifierProvider.overrideWith(() => fake)],
      child: MaterialApp(
        home: AdminProfileScreen(resolvedCount: resolved, bansCount: bans),
      ),
    );

void main() {
  group('AdminProfileScreen', () {
    testWidgets('renders username derived from email prefix', (tester) async {
      final fake = _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(uid: 'u1', email: 'superadmin@cozytalk.com'),
        ),
      );
      await tester.pumpWidget(_build(fake));
      await tester.pumpAndSettle();

      expect(find.text('superadmin'), findsOneWidget);
      expect(find.text('superadmin@cozytalk.com'), findsOneWidget);
    });

    testWidgets('falls back to displayName when email has no @ symbol', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(
            uid: 'u2',
            email: 'notanemail',
            displayName: 'Modkun',
          ),
        ),
      );
      await tester.pumpWidget(_build(fake));
      await tester.pumpAndSettle();

      expect(find.text('Modkun'), findsOneWidget);
    });

    testWidgets(
      'falls back to Admin when email and displayName are both absent',
      (tester) async {
        final fake = _FakeAuthNotifier(
          initial: AuthState(
            status: AuthStatus.authenticated,
            user: const AuthUser(uid: 'u3'),
          ),
        );
        await tester.pumpWidget(_build(fake));
        await tester.pumpAndSettle();

        expect(find.text('Admin'), findsOneWidget);
      },
    );

    testWidgets('shows resolved and bans counts passed from parent', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(uid: 'u4', email: 'mod@cozytalk.com'),
        ),
      );
      await tester.pumpWidget(_build(fake, resolved: 12, bans: 3));
      await tester.pumpAndSettle();

      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('tapping Log out button shows confirmation overlay', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(uid: 'u5', email: 'admin@cozytalk.com'),
        ),
      );
      await tester.pumpWidget(_build(fake));
      await tester.pumpAndSettle();

      expect(find.text('Log out of CozyTalk?'), findsNothing);
      await tester.tap(find.text('Log out'));
      await tester.pump();
      expect(find.text('Log out of CozyTalk?'), findsOneWidget);
    });

    testWidgets('tapping Cancel in overlay hides it without calling signOut', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(uid: 'u6', email: 'admin@cozytalk.com'),
        ),
      );
      await tester.pumpWidget(_build(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pump();
      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(find.text('Log out of CozyTalk?'), findsNothing);
      expect(fake.signOutCount, 0);
    });

    testWidgets('confirming logout calls signOut on authNotifierProvider', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(
        initial: AuthState(
          status: AuthStatus.authenticated,
          user: const AuthUser(uid: 'u7', email: 'admin@cozytalk.com'),
        ),
      );
      await tester.pumpWidget(_build(fake));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log out'));
      await tester.pump();

      // Two 'Log out' texts exist when overlay is shown; tap the last one (inside overlay).
      await tester.tap(find.text('Log out').last);
      await tester.pump();

      expect(fake.signOutCount, 1);
    });

    group('accessibility', () {
      testWidgets('screen renders without semantic errors', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final fake = _FakeAuthNotifier(
            initial: AuthState(
              status: AuthStatus.authenticated,
              user: const AuthUser(uid: 'u8', email: 'admin@cozytalk.com'),
            ),
          );
          await tester.pumpWidget(_build(fake));
          await tester.pumpAndSettle();
          expect(find.byType(AdminProfileScreen), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
