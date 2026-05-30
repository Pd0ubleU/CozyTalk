import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/profile/domain/entities/profile_user.dart';
import 'package:mobile/features/profile/presentation/providers/profile_provider.dart';
import 'package:mobile/screens/profile_edit_screen.dart';
import 'package:mobile/shared/connectivity_provider.dart';
import 'package:mobile/shared/network_info.dart';
import '../shared/fake_network_info.dart';

class _FakeProfileNotifier extends ProfileNotifier {
  final ProfileState _initial;
  int updateDisplayNameCount = 0;
  int updateInterestCount = 0;
  String? lastUid;
  String? lastDisplayName;
  String? lastInterest;

  _FakeProfileNotifier({ProfileState initial = const ProfileState()})
    : _initial = initial;

  @override
  ProfileState build() => _initial;

  @override
  Future<void> load(String uid) async {}

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {
    updateDisplayNameCount++;
    lastUid = uid;
    lastDisplayName = displayName;
  }

  @override
  Future<void> updateInterest(String uid, String interest) async {
    updateInterestCount++;
    lastInterest = interest;
  }

  @override
  Future<void> updateThoughts(String uid, String thoughts) async {}
}

class _FakeErrorProfileNotifier extends ProfileNotifier {
  @override
  ProfileState build() => const ProfileState(
    profile: ProfileUser(uid: 'test-uid', displayName: 'Dave'),
  );

  @override
  Future<void> load(String uid) async {}

  @override
  Future<void> updateDisplayName(String uid, String displayName) async {
    state = state.copyWith(isLoading: false, error: 'Something went wrong');
  }

  @override
  Future<void> updateInterest(String uid, String interest) async {}

  @override
  Future<void> updateThoughts(String uid, String thoughts) async {}
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
  Future<void> signOut() async {}

  @override
  Future<void> signInAnonymously() async {}

  @override
  Future<void> signInWithGoogle() async {}
}

const _auth = AuthState(
  status: AuthStatus.authenticated,
  user: AuthUser(uid: 'test-uid'),
);

Widget _buildScreen(
  ProfileNotifier profileFake, {
  AuthState auth = _auth,
  NetworkInfo? networkInfo,
}) {
  return ProviderScope(
    overrides: [
      profileNotifierProvider.overrideWith(() => profileFake),
      authNotifierProvider.overrideWith(() => _FakeAuthNotifier(initial: auth)),
      if (networkInfo != null)
        networkInfoProvider.overrideWithValue(networkInfo),
    ],
    child: const MaterialApp(home: ProfileEditScreen()),
  );
}

/// Save button sits below a Spacer inside SliverFillRemaining and falls
/// outside the default 800×600 test viewport. A taller surface is required.
void _useTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
}

Future<void> _tapSave(WidgetTester tester) async {
  await tester.tap(find.text('Save'));
  await tester.pump();
}

void main() {
  group('ProfileEditScreen', () {
    testWidgets('renders Username and Interest fields', (tester) async {
      _useTallSurface(tester);
      addTearDown(tester.view.reset);
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildScreen(fake));

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Interest'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('pre-fills controllers from profileNotifierProvider', (
      tester,
    ) async {
      final fake = _FakeProfileNotifier(
        initial: const ProfileState(
          profile: ProfileUser(
            uid: 'test-uid',
            displayName: 'Alice',
            interest: 'coding',
          ),
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));

      expect(find.widgetWithText(TextField, 'Alice'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'coding'), findsOneWidget);
    });

    testWidgets(
      'shows username required error when Save tapped with empty username',
      (tester) async {
        _useTallSurface(tester);
        addTearDown(tester.view.reset);
        final fake = _FakeProfileNotifier();
        await tester.pumpWidget(_buildScreen(fake));

        await _tapSave(tester);

        expect(find.text('*Username is required'), findsOneWidget);
        expect(fake.updateDisplayNameCount, 0);
      },
    );

    testWidgets('calls updateDisplayName and updateInterest on valid save', (
      tester,
    ) async {
      _useTallSurface(tester);
      addTearDown(tester.view.reset);
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildScreen(fake));

      await tester.enterText(find.byType(TextField).first, 'Bob');
      await _tapSave(tester);

      expect(fake.updateDisplayNameCount, 1);
      expect(fake.lastDisplayName, 'Bob');
      expect(fake.lastUid, 'test-uid');
      expect(fake.updateInterestCount, 1);
    });

    testWidgets('trims whitespace before calling notifier', (tester) async {
      _useTallSurface(tester);
      addTearDown(tester.view.reset);
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(_buildScreen(fake));

      await tester.enterText(find.byType(TextField).first, '  Carol  ');
      await _tapSave(tester);

      expect(fake.lastDisplayName, 'Carol');
    });

    testWidgets('shows CircularProgressIndicator when isLoading is true', (
      tester,
    ) async {
      final fake = _FakeProfileNotifier(
        initial: const ProfileState(isLoading: true),
      );
      await tester.pumpWidget(_buildScreen(fake));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Save'), findsNothing);
    });

    testWidgets('does not call notifier when isLoading is true', (
      tester,
    ) async {
      final fake = _FakeProfileNotifier(
        initial: const ProfileState(
          profile: ProfileUser(uid: 'test-uid', displayName: 'Dave'),
          isLoading: true,
        ),
      );
      await tester.pumpWidget(_buildScreen(fake));

      await tester.tap(find.byType(GestureDetector).last, warnIfMissed: false);
      await tester.pump();

      expect(fake.updateDisplayNameCount, 0);
    });

    testWidgets('shows snackbar when notifier emits error during save', (
      tester,
    ) async {
      _useTallSurface(tester);
      addTearDown(tester.view.reset);
      final fake = _FakeErrorProfileNotifier();
      await tester.pumpWidget(_buildScreen(fake));

      await tester.enterText(find.byType(TextField).first, 'Dave');
      await _tapSave(tester);
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    // ── offline ───────────────────────────────────────────────────────────────

    testWidgets('Save button shows grey background when offline', (
      tester,
    ) async {
      _useTallSurface(tester);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _buildScreen(
          _FakeProfileNotifier(),
          networkInfo: FakeNetworkInfo(isOnline: false),
        ),
      );
      await tester.pump();
      final greyButton = find.byWidgetPredicate(
        (w) =>
            w is Container &&
            (w.decoration as BoxDecoration?)?.color == Colors.grey.shade200,
      );
      expect(greyButton, findsOneWidget);
    });

    testWidgets('tapping Save offline shows SnackBar, does not call notifier', (
      tester,
    ) async {
      _useTallSurface(tester);
      addTearDown(tester.view.reset);
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(
        _buildScreen(fake, networkInfo: FakeNetworkInfo(isOnline: false)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Alice');
      await _tapSave(tester);

      expect(
        find.text("You're offline. Changes require a connection."),
        findsOneWidget,
      );
      expect(fake.updateDisplayNameCount, 0);
    });

    testWidgets('tapping Save online calls notifier', (tester) async {
      _useTallSurface(tester);
      addTearDown(tester.view.reset);
      final fake = _FakeProfileNotifier();
      await tester.pumpWidget(
        _buildScreen(fake, networkInfo: FakeNetworkInfo(isOnline: true)),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'Alice');
      await _tapSave(tester);

      expect(fake.updateDisplayNameCount, 1);
    });

    testWidgets('OfflineChip visible when offline', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          _FakeProfileNotifier(),
          networkInfo: FakeNetworkInfo(isOnline: false),
        ),
      );
      await tester.pump();
      expect(find.text('Offline'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          final fake = _FakeProfileNotifier(
            initial: const ProfileState(
              profile: ProfileUser(uid: 'test-uid', interest: 'music'),
            ),
          );
          await tester.pumpWidget(_buildScreen(fake));
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
          expect(find.bySemanticsLabel('Clear'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
