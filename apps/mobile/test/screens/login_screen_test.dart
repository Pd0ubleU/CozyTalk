import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';

class _FakeAuthNotifier extends AuthNotifier {
  int signInCount = 0;
  int signInWithGoogleCount = 0;
  int signInAnonymouslyCount = 0;

  final AuthState _initial;
  _FakeAuthNotifier({AuthState initial = const AuthState()})
    : _initial = initial;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => signInCount++;

  @override
  Future<void> signInWithGoogle() async => signInWithGoogleCount++;

  @override
  Future<void> signInAnonymously() async => signInAnonymouslyCount++;

  @override
  Future<void> signUp({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeNetworkInfo implements NetworkInfo {
  final bool _isOnline;
  _FakeNetworkInfo({bool isOnline = true}) : _isOnline = isOnline;

  @override
  Stream<bool> get onConnectivityChanged => Stream.value(_isOnline);

  @override
  Future<bool> get isConnected async => _isOnline;
}

Widget _build(_FakeAuthNotifier fake, {NetworkInfo? networkInfo}) =>
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => fake),
        networkInfoProvider.overrideWithValue(
          networkInfo ?? _FakeNetworkInfo(isOnline: true),
        ),
      ],
      child: const MaterialApp(home: LoginScreen()),
    );

void main() {
  group('LoginScreen (production)', () {
    testWidgets('renders email field, password field and Login button', (
      tester,
    ) async {
      await tester.pumpWidget(_build(_FakeAuthNotifier()));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('renders Google and guest buttons', (tester) async {
      await tester.pumpWidget(_build(_FakeAuthNotifier()));
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Login as a guest'), findsOneWidget);
    });

    testWidgets('shows password required error on empty submit', (
      tester,
    ) async {
      await tester.pumpWidget(_build(_FakeAuthNotifier()));
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('shows short-password error when password is under 6 chars', (
      tester,
    ) async {
      await tester.pumpWidget(_build(_FakeAuthNotifier()));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'abc',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();
      expect(find.text('At least 6 characters.'), findsOneWidget);
    });

    testWidgets('calls signIn on valid submit', (tester) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_build(fake));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your email'),
        'user@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Enter your password'),
        'password123',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();
      expect(fake.signInCount, 1);
    });

    testWidgets('shows spinner and disables Login button while loading', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier(
        initial: const AuthState(status: AuthStatus.loading),
      );
      await tester.pumpWidget(_build(fake));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final btn = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('shows error snackbar when auth state emits a new error', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_build(fake));
      fake.state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: 'Wrong password.',
      );
      await tester.pump();
      expect(find.text('Wrong password.'), findsOneWidget);
    });

    testWidgets('calls signInWithGoogle when Google button is tapped', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_build(fake));
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(fake.signInWithGoogleCount, 1);
    });

    testWidgets('calls signInAnonymously when guest link is tapped', (
      tester,
    ) async {
      final fake = _FakeAuthNotifier();
      await tester.pumpWidget(_build(fake));
      await tester.ensureVisible(find.text('Login as a guest'));
      await tester.pump();
      await tester.tap(find.text('Login as a guest'), warnIfMissed: false);
      await tester.pump();
      expect(fake.signInAnonymouslyCount, 1);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_build(_FakeAuthNotifier()));
          await tester.pumpAndSettle();
          // tooltip alternates between 'Show password' and 'Hide password' based
          // on _obscurePassword state; default is obscured so 'Show password' is active.
          // Flutter surfaces tooltip text as a semantics tooltip (not label), so
          // byTooltip is the correct finder here.
          expect(find.byTooltip('Show password'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
