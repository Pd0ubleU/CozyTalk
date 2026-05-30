import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/matchmaking/presentation/providers/matchmaking_provider.dart';
import 'package:mobile/screens/select_background_screen.dart';
import 'package:mobile/theme/app_routes.dart';

class _FakeMatchmakingNotifier extends MatchmakingNotifier {
  final MatchmakingState _initial;
  String? lastBackgroundTheme;

  _FakeMatchmakingNotifier({
    MatchmakingState initial = const MatchmakingState(),
  }) : _initial = initial;

  @override
  MatchmakingState build() => _initial;

  @override
  void setBackgroundTheme(String? theme) => lastBackgroundTheme = theme;

  @override
  Future<void> join1v1Pool() async {}

  @override
  Future<void> joinGroupRoom() async {}

  @override
  Future<void> createCustomRoom() async {}

  @override
  Future<void> joinRoomById(String roomId) async {}

  @override
  Future<void> cancelSearch() async {}

  @override
  Future<void> setRoomLock({required bool isLocked}) async {}

  @override
  Future<void> leaveRoom() async {}

  @override
  void setInterestText(String text) {}

  @override
  Future<void> loadSavedInterestText() async {}
}

Widget _build({String roomType = '1v1', _FakeMatchmakingNotifier? fake}) =>
    ProviderScope(
      overrides: [
        if (fake != null) matchmakingNotifierProvider.overrideWith(() => fake),
      ],
      child: MaterialApp(
        routes: {
          AppRoutes.findingRoom: (ctx) {
            final args =
                ModalRoute.of(ctx)?.settings.arguments as Map<String, dynamic>?;
            return Scaffold(
              body: Column(
                children: [
                  const Text('finding-room'),
                  Text(args?['roomType'] as String? ?? ''),
                  Text(args?['roomName'] as String? ?? ''),
                ],
              ),
            );
          },
        },
        home: SelectBackgroundScreen(roomType: roomType),
      ),
    );

void main() {
  group('SelectBackgroundScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.byType(SelectBackgroundScreen), findsOneWidget);
    });

    testWidgets('shows Select room type header', (tester) async {
      await tester.pumpWidget(_build());
      expect(find.text('Select room type'), findsOneWidget);
    });

    testWidgets('shows all four location cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_build());
      await tester.pump();

      expect(find.text('Kao Tapu'), findsOneWidget);
      expect(find.text('Red Lotus Lake'), findsOneWidget);
      expect(find.text('The Sea of Cloud'), findsOneWidget);
      expect(find.text('Lumphini Park'), findsOneWidget);
    });

    testWidgets("Let's go! button is disabled before any selection", (
      tester,
    ) async {
      await tester.pumpWidget(_build());
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Let's go!"),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets("Let's go! button enables after selecting a location", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_build());
      await tester.pump();

      await tester.tap(find.text('Kao Tapu'));
      await tester.pump();

      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, "Let's go!"),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets(
      "Let's go! calls setBackgroundTheme with selected location ID",
      (tester) async {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final fake = _FakeMatchmakingNotifier();
        await tester.pumpWidget(_build(fake: fake));
        await tester.pump();

        await tester.tap(find.text('Kao Tapu'));
        await tester.pump();

        await tester.tap(find.widgetWithText(ElevatedButton, "Let's go!"));
        await tester.pump();

        expect(fake.lastBackgroundTheme, 'kao_tapu');
      },
    );

    testWidgets("Let's go! navigates to findingRoom with correct args", (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final fake = _FakeMatchmakingNotifier();
      await tester.pumpWidget(_build(roomType: '1v1', fake: fake));
      await tester.pump();

      await tester.tap(find.text('Red Lotus Lake'));
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, "Let's go!"));
      await tester.pumpAndSettle();

      expect(find.text('finding-room'), findsOneWidget);
      expect(find.text('1v1'), findsOneWidget);
      expect(find.text('Red Lotus Lake'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_build());
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
