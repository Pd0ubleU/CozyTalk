import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/choose_room_type_screen.dart';

void main() {
  group('ChooseRoomTypeScreen', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChooseRoomTypeScreen()));
      expect(find.byType(ChooseRoomTypeScreen), findsOneWidget);
    });

    testWidgets('shows header title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChooseRoomTypeScreen()));
      expect(find.text('Choose your room type'), findsOneWidget);
    });

    testWidgets('shows all three room type cards', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: ChooseRoomTypeScreen()));
      expect(find.text('1 on 1'), findsOneWidget);
      expect(find.text('Group'), findsOneWidget);
      expect(find.text('Create Group Room'), findsOneWidget);
    });

    testWidgets('Join Room button is disabled before any selection', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ChooseRoomTypeScreen()));
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Join Room'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('Join Room button enables after tapping a card', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ChooseRoomTypeScreen()));
      await tester.tap(find.text('1 on 1'));
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Join Room'),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Join Room button enables after tapping Create Group Room', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: ChooseRoomTypeScreen()));
      await tester.tap(find.text('Create Group Room'));
      await tester.pump();
      final btn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Join Room'),
      );
      expect(btn.onPressed, isNotNull);
    });

    group('accessibility', () {
      testWidgets('interactive elements have semantic labels', (tester) async {
        final handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            const MaterialApp(home: ChooseRoomTypeScreen()),
          );
          await tester.pumpAndSettle();
          expect(find.bySemanticsLabel('Go back'), findsOneWidget);
          // 'Close' is an IconButton tooltip inside the join-group dialog;
          // open the dialog first, then assert via byTooltip.
          await tester.tap(find.text('Group'));
          await tester.pump();
          await tester.tap(find.widgetWithText(ElevatedButton, 'Join Room'));
          await tester.pumpAndSettle();
          expect(find.byTooltip('Close'), findsOneWidget);
        } finally {
          handle.dispose();
        }
      });
    });
  });
}
