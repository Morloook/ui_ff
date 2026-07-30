import 'package:ffmpeg_ui/models/command_models.dart';
import 'package:ffmpeg_ui/models/workflow_models.dart';
import 'package:ffmpeg_ui/ui/dialogs/workflow_command_editor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'final workflow arguments can be edited without changing executable',
    (tester) async {
      const generated = WorkflowDraft(
        name: 'Test',
        steps: [
          WorkflowStep(
            name: 'Etap 1',
            command: CommandDraft(
              executable: '/usr/bin/ffmpeg',
              arguments: [
                '-hide_banner',
                '-i',
                'plik wejściowy.mp4',
                'wynik.mp4',
              ],
            ),
          ),
        ],
      );
      WorkflowDraft? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  result = await showWorkflowCommandEditorDialog(
                    context: context,
                    workflow: generated,
                  );
                },
                child: const Text('Edytuj'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Edytuj'));
      await tester.pumpAndSettle();
      expect(find.text('Ręczna edycja końcowych poleceń'), findsOneWidget);

      await tester.enterText(
        find.byKey(const ValueKey('workflow-arguments-0')),
        '-loglevel info -i "inny plik.mp4" "nowy wynik.mp4"',
      );
      await tester.tap(find.text('Zastosuj i przejdź dalej'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.steps.single.command.executable, '/usr/bin/ffmpeg');
      expect(result!.steps.single.command.arguments, [
        '-loglevel',
        'info',
        '-i',
        'inny plik.mp4',
        'nowy wynik.mp4',
      ]);
    },
  );
}
