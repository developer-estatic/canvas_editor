import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_canvas_editor/flutter_canvas_editor.dart';

DesignDocument _sampleDoc() {
  return const DesignDocument(
    id: 'doc_1',
    version: 1,
    width: 1080,
    height: 1080,
    nodes: [
      BackgroundNode(
        id: 'bg',
        frame: Rect.fromLTWH(0, 0, 1080, 1080),
        zIndex: 0,
        color: '#FFF5F0E8',
      ),
      TextNode(
        id: 't1',
        frame: Rect.fromLTWH(100, 100, 400, 80),
        zIndex: 1,
        text: 'Hello',
        fontFamily: 'Inter',
        fontSize: 32,
        textColor: '#FF112233',
        textAlign: 'center',
      ),
      ImageNode(
        id: 'i1',
        frame: Rect.fromLTWH(200, 300, 200, 200),
        zIndex: 2,
        localPath: '/tmp/photo.jpg',
        fit: 'cover',
      ),
    ],
  );
}

void main() {
  group('DesignDocument JSON', () {
    test('round-trips built-in node types', () {
      final original = _sampleDoc();
      final restored = DesignDocument.fromJson(original.toJson());
      expect(restored, original);
      expect(restored.nodes[1], isA<TextNode>());
      expect((restored.nodes[1] as TextNode).fontFamily, 'Inter');
    });

    test('omitted fontFamily deserializes as null (platform default)', () {
      final json = <String, dynamic>{
        'id': 'd',
        'version': 1,
        'width': 100.0,
        'height': 100.0,
        'nodes': <dynamic>[
          <String, dynamic>{
            'id': 't',
            'type': 'text',
            'frame': <String, dynamic>{
              'x': 0,
              'y': 0,
              'width': 50,
              'height': 20,
            },
            'text': 'x',
            'style': <String, dynamic>{},
            'zIndex': 1,
          },
        ],
      };
      final doc = DesignDocument.fromJson(json);
      expect((doc.nodes.single as TextNode).fontFamily, isNull);
    });
  });

  group('CustomNodeRegistry isolation', () {
    test('two Controllers do not share custom types', () {
      final typeA = CustomNodeType<TextNode>(
        type: 'badge_a',
        fromJson: TextNode.fromJson,
        builder: (_, __) => const SizedBox.shrink(),
      );
      final typeB = CustomNodeType<TextNode>(
        type: 'badge_b',
        fromJson: TextNode.fromJson,
        builder: (_, __) => const SizedBox.shrink(),
      );

      final a = CanvasEditorController(customNodeTypes: [typeA]);
      final b = CanvasEditorController(customNodeTypes: [typeB]);

      expect(a.customNodeRegistry.resolve('badge_a'), isNotNull);
      expect(a.customNodeRegistry.resolve('badge_b'), isNull);
      expect(b.customNodeRegistry.resolve('badge_b'), isNotNull);
      expect(b.customNodeRegistry.resolve('badge_a'), isNull);

      a.dispose();
      b.dispose();
    });
  });
}
