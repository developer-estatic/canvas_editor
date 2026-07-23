import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_canvas_editor/flutter_canvas_editor.dart';
import 'package:flutter_canvas_editor/src/canvas_editor/canvas_painter.dart';

void main() {
  late DesignDocument doc;
  late CoordinateSystem coords;

  setUp(() {
    doc = const DesignDocument(
      id: 'hit',
      version: 1,
      width: 1000,
      height: 1000,
      nodes: [
        BackgroundNode(
          id: 'bg',
          frame: Rect.fromLTWH(0, 0, 1000, 1000),
          zIndex: 0,
          color: '#FFFFFFFF',
        ),
        TextNode(
          id: 't1',
          frame: Rect.fromLTWH(100, 100, 200, 80),
          zIndex: 1,
          text: 'Hit me',
        ),
        ImageNode(
          id: 'i1',
          frame: Rect.fromLTWH(400, 400, 100, 100),
          zIndex: 2,
          localPath: '/tmp/a.png',
        ),
      ],
    );
    // Identity-ish fit: scale 1, offset zero → screen == document.
    coords = CoordinateSystem(
      width: 1000,
      height: 1000,
      viewportScale: 1,
      viewportOffset: Offset.zero,
    );
  });

  test('hits topmost non-background node', () {
    final hit = CanvasHitTest.hitTestNode(const Offset(150, 140), doc, coords);
    expect(hit?.id, 't1');
  });

  test('misses empty space and Background Fill', () {
    expect(
      CanvasHitTest.hitTestNode(const Offset(10, 10), doc, coords),
      isNull,
    );
    // Center of bg only — no content node there
    expect(
      CanvasHitTest.hitTestNode(const Offset(50, 50), doc, coords),
      isNull,
    );
  });

  test('respects z-order when nodes overlap', () {
    final overlapping = DesignDocument(
      id: 'o',
      version: 1,
      width: 1000,
      height: 1000,
      nodes: [
        const BackgroundNode(
          id: 'bg',
          frame: Rect.fromLTWH(0, 0, 1000, 1000),
          zIndex: 0,
          color: '#FFFFFFFF',
        ),
        const TextNode(
          id: 'low',
          frame: Rect.fromLTWH(100, 100, 200, 200),
          zIndex: 1,
          text: 'low',
        ),
        const ImageNode(
          id: 'high',
          frame: Rect.fromLTWH(100, 100, 200, 200),
          zIndex: 5,
          localPath: '/tmp/x.png',
        ),
      ],
    );
    final hit = CanvasHitTest.hitTestNode(
      const Offset(150, 150),
      overlapping,
      coords,
    );
    expect(hit?.id, 'high');
  });

  test('CoordinateSystem round-trips document ↔ screen', () {
    final scaled = CoordinateSystem(
      width: 1000,
      height: 1000,
      viewportScale: 0.5,
      viewportOffset: const Offset(20, 40),
    );
    const docPt = Offset(200, 100);
    final screen = scaled.docToScreen(docPt);
    expect(screen, const Offset(120, 90));
    expect(scaled.screenToDoc(screen), docPt);
  });
}
