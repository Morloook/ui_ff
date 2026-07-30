import 'package:ffmpeg_ui/ui/dialogs/scripts_help_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('scripts help explains limits and shows a compatible example', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showScriptsHelpDialog(context),
                child: const Text('Otwórz pomoc'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Otwórz pomoc'));
    await tester.pumpAndSettle();

    expect(find.text('Pomoc — automatyczny importer skryptów'), findsOneWidget);
    expect(find.text('Ograniczenia'), findsOneWidget);

    await tester.tap(find.text('Przykład'));
    await tester.pumpAndSettle();

    expect(find.text('Kopiuj przykład'), findsOneWidget);
    expect(find.textContaining('VIDEO_CODEC="libx264"'), findsOneWidget);
    expect(find.textContaining('ffmpeg "\$OVERWRITE"'), findsOneWidget);
  });
}
