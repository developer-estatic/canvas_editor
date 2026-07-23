import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_canvas_editor/flutter_canvas_editor.dart';

void main() {
  late CanvasEditorController controller;
  final committed = <DesignDocument>[];

  setUp(() {
    committed.clear();
    controller = CanvasEditorController(
      initialDocument: const DesignDocument(
        id: 'hist',
        version: 1,
        width: 1080,
        height: 1080,
        nodes: [
          BackgroundNode(
            id: 'bg',
            frame: Rect.fromLTWH(0, 0, 1080, 1080),
            zIndex: 0,
            color: '#FFFFFFFF',
          ),
          TextNode(
            id: 't1',
            frame: Rect.fromLTWH(100, 100, 400, 80),
            zIndex: 1,
            text: 'Hello',
            fontSize: 24,
          ),
        ],
      ),
      onDocumentChanged: committed.add,
    );
  });

  tearDown(() => controller.dispose());

  test('addTextNode is a Committed Change', () async {
    controller.addTextNode(text: 'New', position: const Offset(10, 10));
    await pumpEventQueue();
    expect(controller.state.canUndo, isTrue);
    expect(committed, isNotEmpty);
    expect(controller.document.nodes.whereType<TextNode>().length, 2);
  });

  test('history session coalesces live updates into one undo step', () async {
    controller.beginHistorySession();
    controller.updateTextStyle('t1', fontSize: 40, recordUndo: false);
    controller.updateTextStyle('t1', fontSize: 56, recordUndo: false);
    controller.commitHistorySession();
    await pumpEventQueue();

    expect((controller.document.nodes[1] as TextNode).fontSize, 56);
    expect(controller.state.canUndo, isTrue);
    expect(committed, isNotEmpty);

    controller.undo();
    await pumpEventQueue();
    expect((controller.document.nodes[1] as TextNode).fontSize, 24);
  });

  test(
    'updateBackground clears Background Fill image (replace-fill)',
    () async {
      controller.setBackgroundImage(assetId: 'https://example.com/bg.png');
      await pumpEventQueue();
      expect(
        controller.document.nodes
            .whereType<BackgroundNode>()
            .single
            .hasBackgroundImage,
        isTrue,
      );

      controller.updateBackground('#FF000000');
      await pumpEventQueue();
      final filled = controller.document.nodes
          .whereType<BackgroundNode>()
          .single;
      expect(filled.color, '#FF000000');
      expect(filled.hasBackgroundImage, isFalse);
    },
  );
}
