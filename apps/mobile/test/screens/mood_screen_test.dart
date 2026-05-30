import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/screens/mood_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';

class _FakeAvatarNotifier extends AvatarNotifier {
  final AvatarState _initial;
  int setMoodCount = 0;
  int setAccessoryCount = 0;
  AvatarOverlay? lastMood;

  _FakeAvatarNotifier({AvatarState initial = const AvatarState()})
    : _initial = initial;

  @override
  AvatarState build() => _initial;

  @override
  Future<void> setMood(AvatarOverlay? v) async {
    setMoodCount++;
    lastMood = v;
  }

  @override
  Future<void> setAccessory(AvatarOverlay? v) async => setAccessoryCount++;
}

class _FakeAvatarDecorationNotifier extends AvatarDecorationNotifier {
  final AvatarDecorationState _initial;
  int updateMoodCount = 0;
  String? lastMoodKey;

  _FakeAvatarDecorationNotifier({
    AvatarDecorationState initial = const AvatarDecorationState(),
  }) : _initial = initial;

  @override
  AvatarDecorationState build() => _initial;

  @override
  Future<void> load(String uid) async {}

  @override
  Future<void> updateMood(String uid, String? moodKey) async {
    updateMoodCount++;
    lastMoodKey = moodKey;
  }
}

class _FakeAvatarDecorationNotifierWithError extends AvatarDecorationNotifier {
  @override
  AvatarDecorationState build() => const AvatarDecorationState();

  @override
  Future<void> load(String uid) async {}

  @override
  Future<void> updateMood(String uid, String? moodKey) async {
    state = state.copyWith(
      status: AvatarDecorationStatus.error,
      error: "You're offline. Changes require a connection.",
    );
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: const AuthUser(uid: 'test-uid'),
  );
}

class _FakeUnauthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

Widget _build(
  _FakeAvatarNotifier fakeAvatar,
  AvatarDecorationNotifier fakeDecoration, {
  AuthNotifier? authNotifier,
}) => ProviderScope(
  overrides: [
    avatarProvider.overrideWith(() => fakeAvatar),
    avatarDecorationNotifierProvider.overrideWith(() => fakeDecoration),
    authNotifierProvider.overrideWith(
      () => authNotifier ?? _FakeAuthNotifier(),
    ),
  ],
  child: const MaterialApp(home: MoodScreen()),
);

void main() {
  group('MoodScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();
      expect(find.byType(MoodScreen), findsOneWidget);
    });

    testWidgets('shows Mood title in header', (tester) async {
      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();
      expect(find.text('Mood'), findsOneWidget);
    });

    testWidgets('shows all 6 mood options', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();

      expect(find.text('Happy'), findsOneWidget);
      expect(find.text('Thrilled'), findsOneWidget);
      expect(find.text('Sad'), findsOneWidget);
      expect(find.text('Lonely'), findsOneWidget);
      expect(find.text('Silly'), findsOneWidget);
      expect(find.text('Grumpy'), findsOneWidget);
    });

    testWidgets('tapping a mood calls setMood on the notifier', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeAvatar = _FakeAvatarNotifier();
      await tester.pumpWidget(
        _build(fakeAvatar, _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();

      await tester.tap(find.text('Thrilled'));
      await tester.pump();

      expect(fakeAvatar.setMoodCount, 1);
      expect(fakeAvatar.lastMood, equals(AvatarOverlays.mood['Thrilled']));
    });

    testWidgets('Save button is present', (tester) async {
      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Save button calls updateMood on avatarDecorationNotifier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeDecoration = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(_build(_FakeAvatarNotifier(), fakeDecoration));
      await tester.pump();

      await tester.tap(find.text('Thrilled'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDecoration.updateMoodCount, 1);
      expect(fakeDecoration.lastMoodKey, 'Thrilled');
    });

    testWidgets('Save is a no-op while status is saving', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeDecoration = _FakeAvatarDecorationNotifier(
        initial: const AvatarDecorationState(
          status: AvatarDecorationStatus.saving,
        ),
      );
      await tester.pumpWidget(_build(_FakeAvatarNotifier(), fakeDecoration));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDecoration.updateMoodCount, 0);
    });

    testWidgets('Save is a no-op when uid is null', (tester) async {
      final fakeDecoration = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(
        _build(
          _FakeAvatarNotifier(),
          fakeDecoration,
          authNotifier: _FakeUnauthNotifier(),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDecoration.updateMoodCount, 0);
    });

    testWidgets('shows error SnackBar when save fails', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifierWithError()),
      );
      await tester.pump();

      await tester.tap(find.text('Thrilled'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(
        find.text("You're offline. Changes require a connection."),
        findsOneWidget,
      );
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Undo'), findsOneWidget);
          expect(find.bySemanticsLabel('Redo'), findsOneWidget);
          expect(find.bySemanticsLabel('Reset mood'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
