import 'package:canvas_editor_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders canvas editor example', (WidgetTester tester) async {
    await tester.pumpWidget(const CanvasEditorExampleApp());
    await tester.pump();

    expect(find.text('Canvas Editor Example'), findsOneWidget);
    expect(find.text('Add text'), findsOneWidget);
  });
}
