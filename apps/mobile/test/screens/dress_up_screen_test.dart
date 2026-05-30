import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/auth/domain/entities/auth_user.dart';
import 'package:mobile/features/auth/presentation/providers/auth_provider.dart';
import 'package:mobile/features/avatar/domain/entities/avatar_decoration.dart';
import 'package:mobile/features/avatar/presentation/providers/avatar_decoration_provider.dart';
import 'package:mobile/screens/dress_up_screen.dart';
import 'package:mobile/shared/avatar_overlay.dart';

class _FakeAvatarNotifier extends AvatarNotifier {
  final AvatarState _initial;
  int setMoodCount = 0;
  int setAccessoryCount = 0;
  AvatarOverlay? lastAccessory;

  _FakeAvatarNotifier({AvatarState initial = const AvatarState()})
    : _initial = initial;

  @override
  AvatarState build() => _initial;

  @override
  Future<void> setMood(AvatarOverlay? v) async => setMoodCount++;

  @override
  Future<void> setAccessory(AvatarOverlay? v) async {
    setAccessoryCount++;
    lastAccessory = v;
  }
}

class _FakeAvatarDecorationNotifier extends AvatarDecorationNotifier {
  final AvatarDecorationState _initial;
  int updateHatCount = 0;
  String? lastHatKey;

  _FakeAvatarDecorationNotifier({
    AvatarDecorationState initial = const AvatarDecorationState(),
  }) : _initial = initial;

  @override
  AvatarDecorationState build() => _initial;

  @override
  Future<void> load(String uid) async {}

  @override
  Future<void> updateHat(String uid, String? hatKey) async {
    updateHatCount++;
    lastHatKey = hatKey;
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => AuthState(
    status: AuthStatus.authenticated,
    user: const AuthUser(uid: 'test-uid'),
  );
}

class _FakeFailingAvatarDecorationNotifier extends AvatarDecorationNotifier {
  @override
  AvatarDecorationState build() => const AvatarDecorationState();

  @override
  Future<void> load(String uid) async {}

  @override
  Future<void> updateHat(String uid, String? hatKey) async {
    state = state.copyWith(
      status: AvatarDecorationStatus.error,
      error: "You're offline. Changes require a connection.",
    );
  }
}

class _FakeSlowDecorationNotifier extends AvatarDecorationNotifier {
  int updateHatCount = 0;
  String? lastHatKey;

  @override
  AvatarDecorationState build() => const AvatarDecorationState();

  @override
  Future<void> load(String uid) async {}

  @override
  Future<void> updateHat(String uid, String? hatKey) async {
    updateHatCount++;
    lastHatKey = hatKey;
  }

  void simulateLoad(String hatKey) {
    state = AvatarDecorationState(decoration: AvatarDecoration(hatKey: hatKey));
  }
}

Widget _build(
  _FakeAvatarNotifier fakeAvatar,
  AvatarDecorationNotifier fakeDecoration,
) => ProviderScope(
  overrides: [
    avatarProvider.overrideWith(() => fakeAvatar),
    avatarDecorationNotifierProvider.overrideWith(() => fakeDecoration),
    authNotifierProvider.overrideWith(() => _FakeAuthNotifier()),
  ],
  child: const MaterialApp(home: DressUpScreen()),
);

void main() {
  group('DressUpScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();
      expect(find.byType(DressUpScreen), findsOneWidget);
    });

    testWidgets('shows Dress up title in header', (tester) async {
      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();
      expect(find.text('Dress up'), findsOneWidget);
    });

    testWidgets('shows all 6 accessory items', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();

      expect(find.text('Cap'), findsOneWidget);
      expect(find.text('Beanie'), findsOneWidget);
      expect(find.text('Witch Hat'), findsOneWidget);
      expect(find.text('Sunglasses'), findsOneWidget);
      expect(find.text('Cat Headband'), findsOneWidget);
      expect(find.text('Crown'), findsOneWidget);
    });

    testWidgets('tapping an accessory calls setAccessory on the notifier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeAvatar = _FakeAvatarNotifier();
      await tester.pumpWidget(
        _build(fakeAvatar, _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();

      await tester.tap(find.text('Cap'));
      await tester.pump();

      expect(fakeAvatar.setAccessoryCount, 1);
      expect(fakeAvatar.lastAccessory, equals(AvatarOverlays.accessory['Cap']));
    });

    testWidgets('Save button is present', (tester) async {
      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeAvatarDecorationNotifier()),
      );
      await tester.pump();
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Save button calls updateHat on avatarDecorationNotifier', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeDecoration = _FakeAvatarDecorationNotifier();
      await tester.pumpWidget(_build(_FakeAvatarNotifier(), fakeDecoration));
      await tester.pump();

      await tester.tap(find.text('Cap'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDecoration.updateHatCount, 1);
      expect(fakeDecoration.lastHatKey, 'Cap');
    });

    testWidgets('pre-fills selected hat from decoration on open', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeDecoration = _FakeAvatarDecorationNotifier(
        initial: const AvatarDecorationState(
          decoration: AvatarDecoration(hatKey: 'Cap'),
        ),
      );
      await tester.pumpWidget(_build(_FakeAvatarNotifier(), fakeDecoration));
      await tester.pump();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDecoration.lastHatKey, 'Cap');
    });

    testWidgets('pre-fills when decoration loads after navigation', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fakeDecoration = _FakeSlowDecorationNotifier();
      await tester.pumpWidget(_build(_FakeAvatarNotifier(), fakeDecoration));
      await tester
          .pump(); // postFrameCallback fires — decoration is null, not yet initialized

      fakeDecoration.simulateLoad('Beanie');
      await tester.pump(); // ref.listen fires, _selected set to 'Beanie'

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(fakeDecoration.updateHatCount, 1);
      expect(fakeDecoration.lastHatKey, 'Beanie');
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
      await tester.pump();

      expect(fakeDecoration.updateHatCount, 0);
    });

    testWidgets('shows error SnackBar and stays open when save fails', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _build(_FakeAvatarNotifier(), _FakeFailingAvatarDecorationNotifier()),
      );
      await tester.pump();

      await tester.tap(find.text('Cap'));
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byType(DressUpScreen), findsOneWidget);
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
          expect(find.bySemanticsLabel('Remove item'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
