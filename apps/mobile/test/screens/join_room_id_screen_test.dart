import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/join_room_id_screen.dart';
import 'package:mobile/theme/app_routes.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

Widget _buildScreen() {
  return const ProviderScope(
    child: MaterialApp(
      home: JoinRoomIdScreen(),
      routes: {AppRoutes.findingRoom: _FakeFindingRoomScreen._builder},
    ),
  );
}

class _FakeFindingRoomScreen extends StatelessWidget {
  const _FakeFindingRoomScreen();

  static Widget _builder(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    return Scaffold(
      body: Column(
        children: [
          const Text('finding-room'),
          Text(args?['roomType'] as String? ?? ''),
          Text(args?['roomId'] as String? ?? ''),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _builder(context);
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('JoinRoomIdScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.byType(JoinRoomIdScreen), findsOneWidget);
    });

    testWidgets('shows Join a Room title', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.text('Join a Room'), findsOneWidget);
    });

    testWidgets('shows Enter room ID instruction', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.text('Enter room ID'), findsOneWidget);
    });

    testWidgets('shows 5 character text fields', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.byType(TextField), findsNWidgets(5));
    });

    testWidgets('shows Join Room button', (tester) async {
      await tester.pumpWidget(_buildScreen());
      expect(find.text('Join Room'), findsOneWidget);
    });

    testWidgets('pressing Join Room with empty fields shows error dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildScreen());

      await tester.tap(find.text('Join Room'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Room ID'), findsOneWidget);
    });

    testWidgets('pressing Join Room with partial input shows error dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildScreen());

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'A');
      await tester.enterText(fields.at(1), 'B');
      await tester.pump();

      await tester.tap(find.text('Join Room'));
      await tester.pumpAndSettle();

      expect(find.text('Invalid Room ID'), findsOneWidget);
    });

    testWidgets('complete 5-char input navigates to findingRoom', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildScreen());

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'A');
      await tester.enterText(fields.at(1), 'B');
      await tester.enterText(fields.at(2), 'C');
      await tester.enterText(fields.at(3), 'D');
      await tester.enterText(fields.at(4), 'E');
      await tester.pump();

      await tester.tap(find.text('Join Room'));
      await tester.pumpAndSettle();

      expect(find.text('finding-room'), findsOneWidget);
    });

    testWidgets('navigates with joinById roomType and correct roomId', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_buildScreen());

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'X');
      await tester.enterText(fields.at(1), 'Y');
      await tester.enterText(fields.at(2), 'Z');
      await tester.enterText(fields.at(3), '1');
      await tester.enterText(fields.at(4), '2');
      await tester.pump();

      await tester.tap(find.text('Join Room'));
      await tester.pumpAndSettle();

      expect(find.text('joinById'), findsOneWidget);
      expect(find.text('XYZ12'), findsOneWidget);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(_buildScreen());
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
