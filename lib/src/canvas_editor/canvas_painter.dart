import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../document/document_color.dart';
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

  /// Used to size selection supersampling to the screen's physical pixels.
  final double devicePixelRatio;

  /// Text node currently edited in place. Its glyphs are drawn by the
  /// overlay field, so the canvas must not paint a second copy underneath.
  final String? editingNodeId;

  CanvasPainter({
    required this.document,
    required this.coords,
    this.selectedNodeId,
    this.imageCache = const {},
    this.theme = const CanvasTheme(),
    this.devicePixelRatio = 1.0,
    this.editingNodeId,
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
    } else if (node is TextNode && node.id != editingNodeId) {
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

  /// Selection chrome is supersampled so rotated edges stay smooth.
  /// Factor tracks [devicePixelRatio] (clamped) so we don't undersample on
  /// high-DPI screens; capped for interactive drag/rotate cost.
  static const double _rotationHandleReach = 30.0;
  static const double _rotationHandleRadius = 5.0;
  static const double _softEdgeExtra = 1.25;

  double get _selectionSupersample =>
      devicePixelRatio.clamp(2.0, 4.0).ceilToDouble();

  void _drawSelectionOverlay(Canvas canvas, DesignNode node) {
    final screenRect = coords.docToScreenRect(node.frame);
    final bounds = _selectionOverlayBounds(screenRect, node.rotation);
    if (bounds.isEmpty) return;

    final ss = _selectionSupersample;
    final pixelW = math.max(1, (bounds.width * ss).ceil());
    final pixelH = math.max(1, (bounds.height * ss).ceil());

    final recorder = ui.PictureRecorder();
    final layer = Canvas(recorder);
    layer.scale(ss);
    layer.translate(-bounds.left, -bounds.top);
    _paintSelectionChrome(layer, node, screenRect);

    final picture = recorder.endRecording();
    final image = picture.toImageSync(pixelW, pixelH);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, pixelW.toDouble(), pixelH.toDouble()),
      bounds,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );
    image.dispose();
  }

  Rect _selectionOverlayBounds(Rect screenRect, double rotationDeg) {
    final pad =
        math.max(theme.handleSize, theme.selectionBorderWidth) / 2 +
        _rotationHandleReach +
        _rotationHandleRadius +
        _softEdgeExtra +
        4;
    final center = screenRect.center;
    final rad = rotationDeg * (math.pi / 180);
    final cosA = math.cos(rad);
    final sinA = math.sin(rad);

    Offset transform(Offset p) {
      final dx = p.dx - center.dx;
      final dy = p.dy - center.dy;
      return Offset(
        center.dx + dx * cosA - dy * sinA,
        center.dy + dx * sinA + dy * cosA,
      );
    }

    final points = <Offset>[
      transform(screenRect.topLeft),
      transform(screenRect.topRight),
      transform(screenRect.bottomLeft),
      transform(screenRect.bottomRight),
      // Rotation stem tip (above top-center in local space).
      transform(
        Offset(screenRect.center.dx, screenRect.top - _rotationHandleReach),
      ),
    ];

    var minX = points.first.dx;
    var minY = points.first.dy;
    var maxX = points.first.dx;
    var maxY = points.first.dy;
    for (final p in points.skip(1)) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  void _paintSelectionChrome(Canvas canvas, DesignNode node, Rect screenRect) {
    final center = screenRect.center;
    final handleSize = theme.handleSize;
    final stroke = theme.selectionBorderWidth;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(node.rotation * (math.pi / 180));
    canvas.translate(-center.dx, -center.dy);

    // Soft underlay hides residual stair-steps at awkward angles.
    final softPaint = Paint()
      ..color = theme.selectionBorderColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    _drawFilledStrokeRect(
      canvas,
      screenRect,
      stroke + _softEdgeExtra,
      softPaint,
    );

    final fillPaint = Paint()
      ..color = theme.selectionBorderColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    _drawFilledStrokeRect(canvas, screenRect, stroke, fillPaint);

    final handleFill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final handleStroke = Paint()
      ..color = theme.handleColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final handleCenters = node is TextNode
        ? [
            Offset(screenRect.left, screenRect.center.dy),
            Offset(screenRect.right, screenRect.center.dy),
          ]
        : [
            screenRect.topLeft,
            screenRect.topRight,
            screenRect.bottomLeft,
            screenRect.bottomRight,
          ];
    for (final handleCenter in handleCenters) {
      final outer = Rect.fromCenter(
        center: handleCenter,
        width: handleSize,
        height: handleSize,
      );
      canvas.drawRect(outer.inflate(stroke / 2), handleStroke);
      canvas.drawRect(outer.deflate(stroke / 2), handleFill);
    }

    final topCenter = Offset(screenRect.center.dx, screenRect.top);
    final rotHandleCenter = Offset(
      topCenter.dx,
      topCenter.dy - _rotationHandleReach,
    );
    final stemPaint = Paint()
      ..color = theme.effectiveRotationHandleColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(topCenter.dx, (topCenter.dy + rotHandleCenter.dy) / 2),
        width: stroke,
        height: (topCenter.dy - rotHandleCenter.dy).abs(),
      ),
      stemPaint,
    );
    canvas.drawCircle(
      rotHandleCenter,
      _rotationHandleRadius + stroke / 2,
      handleStroke,
    );
    canvas.drawCircle(
      rotHandleCenter,
      math.max(0.5, _rotationHandleRadius - stroke / 2),
      handleFill,
    );

    canvas.restore();
  }

  /// Stroke-like border as a filled even-odd ring (outer − inner).
  void _drawFilledStrokeRect(
    Canvas canvas,
    Rect rect,
    double strokeWidth,
    Paint paint,
  ) {
    final half = strokeWidth / 2;
    final outer = rect.inflate(half);
    final inner = rect.deflate(half);
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(outer);
    if (inner.width > 0 && inner.height > 0) {
      path.addRect(inner);
    }
    canvas.drawPath(path, paint);
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
      old.coords.viewportOffset != coords.viewportOffset ||
      old.devicePixelRatio != devicePixelRatio ||
      old.theme != theme ||
      old.editingNodeId != editingNodeId;
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
    return localX >= -halfW &&
        localX <= halfW &&
        localY >= -halfH &&
        localY <= halfH;
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
    final positions = <Offset>[Offset(-halfW, 0), Offset(halfW, 0)];
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
          case 0:
            return 'tl';
          case 1:
            return 'tr';
          case 2:
            return 'bl';
          case 3:
            return 'br';
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

Color _parseHex(String hex) => decodeDocumentColor(hex);

FontWeight _fontWeight(int w) {
  switch (w) {
    case 100:
      return FontWeight.w100;
    case 200:
      return FontWeight.w200;
    case 300:
      return FontWeight.w300;
    case 400:
      return FontWeight.normal;
    case 500:
      return FontWeight.w500;
    case 600:
      return FontWeight.w600;
    case 700:
      return FontWeight.bold;
    case 800:
      return FontWeight.w800;
    case 900:
      return FontWeight.w900;
    default:
      return FontWeight.normal;
  }
}

TextAlign _textAlign(String a) {
  switch (a) {
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    default:
      return TextAlign.left;
  }
}
