import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';

// ── Fakes ──────────────────────────────────────────────────────────────────────

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier({required AuthState initial}) : _initial = initial;

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

// ── Router under test ──────────────────────────────────────────────────────────
//
// Mirrors _MainUIAuthRouter routing logic from main.dart without importing the
// private class or rendering heavyweight screens. Uses labelled placeholders so
// tests can assert which route was chosen.

class _TestAuthRouter extends ConsumerWidget {
  const _TestAuthRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final isAdmin =
        authState.user?.email?.toLowerCase().endsWith('@cozytalk.com') ?? false;
    return switch (authState.status) {
      AuthStatus.authenticated =>
        isAdmin
            ? const _Placeholder(key: Key('admin'))
            : const _Placeholder(key: Key('home')),
      AuthStatus.idle => const CircularProgressIndicator(),
      _ => const _Placeholder(key: Key('login')),
    };
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ── Helper ─────────────────────────────────────────────────────────────────────

Widget _buildRouter(AuthState initial) => ProviderScope(
  overrides: [
    authNotifierProvider.overrideWith(
      () => _FakeAuthNotifier(initial: initial),
    ),
  ],
  child: const MaterialApp(home: _TestAuthRouter()),
);

// ── Tests ──────────────────────────────────────────────────────────────────────

void main() {
  group('_MainUIAuthRouter routing', () {
    testWidgets('routes @cozytalk.com user to AdminConsoleScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRouter(
          AuthState(
            status: AuthStatus.authenticated,
            user: const AuthUser(uid: 'admin1', email: 'admin@cozytalk.com'),
          ),
        ),
      );

      expect(find.byKey(const Key('admin')), findsOneWidget);
      expect(find.byKey(const Key('home')), findsNothing);
    });

    testWidgets('routes @cozytalk.com user case-insensitively to admin', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRouter(
          AuthState(
            status: AuthStatus.authenticated,
            user: const AuthUser(uid: 'admin2', email: 'Admin@CozyTalk.COM'),
          ),
        ),
      );

      expect(find.byKey(const Key('admin')), findsOneWidget);
      expect(find.byKey(const Key('home')), findsNothing);
    });

    testWidgets('routes regular user to HomeScreen', (tester) async {
      await tester.pumpWidget(
        _buildRouter(
          AuthState(
            status: AuthStatus.authenticated,
            user: const AuthUser(uid: 'user1', email: 'user@example.com'),
          ),
        ),
      );

      expect(find.byKey(const Key('home')), findsOneWidget);
      expect(find.byKey(const Key('admin')), findsNothing);
    });

    testWidgets('routes anonymous user (no email) to HomeScreen', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRouter(
          AuthState(
            status: AuthStatus.authenticated,
            user: const AuthUser(uid: 'anon1'),
          ),
        ),
      );

      expect(find.byKey(const Key('home')), findsOneWidget);
      expect(find.byKey(const Key('admin')), findsNothing);
    });

    testWidgets('shows spinner when status is idle', (tester) async {
      await tester.pumpWidget(
        _buildRouter(const AuthState(status: AuthStatus.idle)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows login when status is unauthenticated', (tester) async {
      await tester.pumpWidget(
        _buildRouter(const AuthState(status: AuthStatus.unauthenticated)),
      );

      expect(find.byKey(const Key('login')), findsOneWidget);
    });
  });
}
