import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../document/models/design_document.dart';
import '../shared/image_load_path.dart';
import '../renderer/coordinate_system.dart';
import '../theme/canvas_theme.dart';

class CanvasPainter extends CustomPainter {
  final DesignDocument document;
  final String? selectedNodeId;
  final CoordinateSystem coords;
  final Map<String, ui.Image> imageCache;
  final CanvasTheme theme;

  CanvasPainter({
    required this.document,
    required this.coords,
    this.selectedNodeId,
    this.imageCache = const {},
    this.theme = const CanvasTheme(),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final sorted = List<DesignNode>.from(document.nodes)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final node in sorted) {
      _drawNode(canvas, node);
    }

    // Draw selection overlay on top
    if (selectedNodeId != null) {
      final node = document.nodes.cast<DesignNode?>().firstWhere(
        (n) => n?.id == selectedNodeId,
        orElse: () => null,
      );
      if (node != null) _drawSelectionOverlay(canvas, node);
    }
  }

  void _drawNode(Canvas canvas, DesignNode node) {
    // Clip to canvas bounds (document size) before drawing each node
    final docRect = Rect.fromLTWH(0, 0, document.width, document.height);
    final screenBounds = coords.docToScreenRect(docRect);
    canvas.save();
    canvas.clipRect(screenBounds);

    final screenRect = coords.docToScreenRect(node.frame);
    final center = screenRect.center;

    // Apply node transform (pivot at frame centre)
    canvas.translate(center.dx, center.dy);
    canvas.rotate(node.rotation * (math.pi / 180));
    canvas.scale(node.scaleX, node.scaleY);
    canvas.translate(-center.dx, -center.dy);

    if (node is BackgroundNode) {
      _drawBackground(canvas, node, screenRect);
    } else if (node is TextNode) {
      final textStyle = TextStyle(
        color: _parseHex(node.textColor),
        fontFamily: node.fontFamily,
        fontSize: node.fontSize * coords.viewportScale,
        fontWeight: _fontWeight(node.fontWeight),
        height: node.lineHeight,
        letterSpacing: node.letterSpacing * coords.viewportScale,
      );
      final tp = TextPainter(
        text: TextSpan(text: node.text, style: textStyle),
        textDirection: TextDirection.ltr,
        textAlign: _textAlign(node.textAlign),
      );
      tp.layout(maxWidth: screenRect.width);
      tp.paint(canvas, screenRect.topLeft);
    } else if (node is ImageNode) {
      final ref = CanvasImageReference.fromImageNode(node);
      final cached = ref.cacheKey != null ? imageCache[ref.cacheKey] : null;
      if (cached != null) {
        _drawImage(canvas, cached, screenRect, node.fit);
      } else {
        final paint = Paint()
          ..color = Colors.grey.shade200
          ..style = PaintingStyle.fill;
        canvas.drawRect(screenRect, paint);
        final border = Paint()
          ..color = Colors.grey.shade400
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawRect(screenRect, border);
      }
    }

    canvas.restore(); // restore clipping and transform
  }

  void _drawSelectionOverlay(Canvas canvas, DesignNode node) {
    final screenRect = coords.docToScreenRect(node.frame);
    final center = screenRect.center;
    final handleSize = theme.handleSize;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(node.rotation * (math.pi / 180));
    canvas.translate(-center.dx, -center.dy);

    // Border
    final borderPaint = Paint()
      ..color = theme.selectionBorderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.selectionBorderWidth;
    canvas.drawRect(screenRect, borderPaint);

    // Resize handles — Text Nodes: side mid-edge only; others: corners
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorder = Paint()
      ..color = theme.handleColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = theme.selectionBorderWidth;

    if (node is TextNode) {
      final sides = [
        Offset(screenRect.left, screenRect.center.dy),
        Offset(screenRect.right, screenRect.center.dy),
      ];
      for (final side in sides) {
        final handleRect = Rect.fromCenter(
          center: side,
          width: handleSize,
          height: handleSize,
        );
        canvas.drawRect(handleRect, handlePaint);
        canvas.drawRect(handleRect, handleBorder);
      }
    } else {
      final corners = [
        screenRect.topLeft,
        screenRect.topRight,
        screenRect.bottomLeft,
        screenRect.bottomRight,
      ];
      for (final corner in corners) {
        final handleRect = Rect.fromCenter(
          center: corner,
          width: handleSize,
          height: handleSize,
        );
        canvas.drawRect(handleRect, handlePaint);
        canvas.drawRect(handleRect, handleBorder);
      }
    }

    // Rotation handle — line + circle above top center
    final topCenter = Offset(screenRect.center.dx, screenRect.top);
    final rotHandleCenter = Offset(topCenter.dx, topCenter.dy - 30);
    final linePaint = Paint()
      ..color = theme.rotationHandleColor
      ..strokeWidth = theme.selectionBorderWidth;
    canvas.drawLine(topCenter, rotHandleCenter, linePaint);
    canvas.drawCircle(rotHandleCenter, 5, handlePaint);
    canvas.drawCircle(rotHandleCenter, 5, handleBorder);

    canvas.restore();
  }

  void _drawBackground(Canvas canvas, BackgroundNode node, Rect screenRect) {
    if (node.hasBackgroundImage) {
      final ref = CanvasImageReference.fromBackgroundNode(node);
      final cached = ref.cacheKey != null ? imageCache[ref.cacheKey] : null;
      if (cached != null) {
        _drawImage(canvas, cached, screenRect, 'cover');
        return;
      }
    }
    final paint = Paint()..color = _parseHex(node.color);
    canvas.drawRect(screenRect, paint);
  }

  void _drawImage(Canvas canvas, ui.Image image, Rect dest, String fit) {
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final srcRect = _srcRectForFit(srcSize, dest.size, fit);
    canvas.drawImageRect(image, srcRect, dest, Paint()..isAntiAlias = true);
  }

  Rect _srcRectForFit(Size src, Size dest, String fit) {
    if (fit == 'cover') {
      final srcAspect = src.width / src.height;
      final destAspect = dest.width / dest.height;
      if (srcAspect > destAspect) {
        final sw = src.height * destAspect;
        return Rect.fromLTWH((src.width - sw) / 2, 0, sw, src.height);
      } else {
        final sh = src.width / destAspect;
        return Rect.fromLTWH(0, (src.height - sh) / 2, src.width, sh);
      }
    }
    return Offset.zero & src;
  }

  @override
  bool shouldRepaint(covariant CanvasPainter old) =>
      old.document != document ||
      old.selectedNodeId != selectedNodeId ||
      old.coords.viewportScale != coords.viewportScale ||
      old.coords.viewportOffset != coords.viewportOffset;
}

/// Hit-test utilities for the canvas editor.
class CanvasHitTest {
  static DesignNode? hitTestNode(
    Offset screenPoint,
    DesignDocument document,
    CoordinateSystem coords,
  ) {
    final sorted = List<DesignNode>.from(document.nodes)
      ..sort((a, b) => b.zIndex.compareTo(a.zIndex));

    for (final node in sorted) {
      if (node is BackgroundNode) continue;
      if (_pointInRotatedRect(screenPoint, node, coords)) return node;
    }
    return null;
  }

  static bool _pointInRotatedRect(
    Offset screenPoint,
    DesignNode node,
    CoordinateSystem coords,
  ) {
    final screenRect = coords.docToScreenRect(node.frame);
    final center = screenRect.center;
    final angleRad = node.rotation * (math.pi / 180);
    final dx = screenPoint.dx - center.dx;
    final dy = screenPoint.dy - center.dy;
    final cosA = math.cos(-angleRad);
    final sinA = math.sin(-angleRad);
    final localX = dx * cosA - dy * sinA;
    final localY = dx * sinA + dy * cosA;
    final halfW = screenRect.width / 2;
    final halfH = screenRect.height / 2;
    return localX >= -halfW && localX <= halfW && localY >= -halfH && localY <= halfH;
  }

  static String? hitTestSideHandle(
    Offset screenPoint,
    DesignNode node,
    CoordinateSystem coords, [
    double handleHitRadius = 15.0,
  ]) {
    if (node is! TextNode) return null;

    final screenRect = coords.docToScreenRect(node.frame);
    final center = screenRect.center;
    final angleRad = node.rotation * (math.pi / 180);
    final dx = screenPoint.dx - center.dx;
    final dy = screenPoint.dy - center.dy;
    final cosA = math.cos(-angleRad);
    final sinA = math.sin(-angleRad);
    final localPt = Offset(dx * cosA - dy * sinA, dx * sinA + dy * cosA);
    final halfW = screenRect.width / 2;
    final positions = <Offset>[
      Offset(-halfW, 0),
      Offset(halfW, 0),
    ];
    for (int i = 0; i < 2; i++) {
      if ((localPt - positions[i]).distance <= handleHitRadius) {
        return i == 0 ? 'ml' : 'mr';
      }
    }
    return null;
  }

  static String? hitTestResizeHandle(
    Offset screenPoint,
    DesignNode node,
    CoordinateSystem coords, [
    double handleHitRadius = 15.0,
  ]) {
    if (node is TextNode) {
      return hitTestSideHandle(screenPoint, node, coords, handleHitRadius);
    }
    return hitTestCornerHandle(screenPoint, node, coords, handleHitRadius);
  }

  static String? hitTestCornerHandle(
    Offset screenPoint,
    DesignNode node,
    CoordinateSystem coords, [
    double handleHitRadius = 15.0,
  ]) {
    final screenRect = coords.docToScreenRect(node.frame);
    final center = screenRect.center;
    final angleRad = node.rotation * (math.pi / 180);
    final dx = screenPoint.dx - center.dx;
    final dy = screenPoint.dy - center.dy;
    final cosA = math.cos(-angleRad);
    final sinA = math.sin(-angleRad);
    final localPt = Offset(dx * cosA - dy * sinA, dx * sinA + dy * cosA);
    final halfW = screenRect.width / 2;
    final halfH = screenRect.height / 2;
    final positions = <Offset>[
      Offset(-halfW, -halfH),
      Offset(halfW, -halfH),
      Offset(-halfW, halfH),
      Offset(halfW, halfH),
    ];
    for (int i = 0; i < 4; i++) {
      if ((localPt - positions[i]).distance <= handleHitRadius) {
        switch (i) {
          case 0: return 'tl';
          case 1: return 'tr';
          case 2: return 'bl';
          case 3: return 'br';
        }
      }
    }
    return null;
  }

  static bool hitTestRotationHandle(
    Offset screenPoint,
    DesignNode node,
    CoordinateSystem coords, [
    double hitRadius = 20.0,
  ]) {
    final screenRect = coords.docToScreenRect(node.frame);
    final center = screenRect.center;
    final angleRad = node.rotation * (math.pi / 180);
    final dx = screenPoint.dx - center.dx;
    final dy = screenPoint.dy - center.dy;
    final cosA = math.cos(-angleRad);
    final sinA = math.sin(-angleRad);
    final localPt = Offset(dx * cosA - dy * sinA, dx * sinA + dy * cosA);
    final halfH = screenRect.height / 2;
    final rotY = -halfH - 30;
    return (localPt - Offset(0, rotY)).distance <= hitRadius;
  }
}

Color _parseHex(String hex) {
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  return Color(int.parse(h, radix: 16));
}

FontWeight _fontWeight(int w) {
  switch (w) {
    case 100: return FontWeight.w100;
    case 200: return FontWeight.w200;
    case 300: return FontWeight.w300;
    case 400: return FontWeight.normal;
    case 500: return FontWeight.w500;
    case 600: return FontWeight.w600;
    case 700: return FontWeight.bold;
    case 800: return FontWeight.w800;
    case 900: return FontWeight.w900;
    default: return FontWeight.normal;
  }
}

TextAlign _textAlign(String a) {
  switch (a) {
    case 'center': return TextAlign.center;
    case 'right': return TextAlign.right;
    default: return TextAlign.left;
  }
}
