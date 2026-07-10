import 'dart:ui';

class CoordinateSystem {
  final double width;
  final double height;
  final double viewportScale;
  final Offset viewportOffset;

  CoordinateSystem({
    required this.width,
    required this.height,
    required this.viewportScale,
    required this.viewportOffset,
  });

  /// Converts a point from Document Space to Screen/Viewport Space.
  Offset docToScreen(Offset docPoint) {
    return Offset(
      docPoint.dx * viewportScale + viewportOffset.dx,
      docPoint.dy * viewportScale + viewportOffset.dy,
    );
  }

  /// Converts a delta/size vector from Document Space to Screen/Viewport Space.
  Offset docToScreenDelta(Offset docDelta) {
    return docDelta * viewportScale;
  }

  /// Converts a point from Screen/Viewport Space back into Document Space.
  Offset screenToDoc(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - viewportOffset.dx) / viewportScale,
      (screenPoint.dy - viewportOffset.dy) / viewportScale,
    );
  }

  /// Converts a delta/size vector from Screen/Viewport Space back into Document Space.
  Offset screenToDocDelta(Offset screenDelta) {
    return screenDelta / viewportScale;
  }

  /// Converts a Rect from Document Space to Screen/Viewport Space.
  Rect docToScreenRect(Rect docRect) {
    final topLeft = docToScreen(Offset(docRect.left, docRect.top));
    final size = docToScreenDelta(Offset(docRect.width, docRect.height));
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, size.dx, size.dy);
  }

  /// Converts a Rect from Screen/Viewport Space to Document Space.
  Rect screenToDocRect(Rect screenRect) {
    final topLeft = screenToDoc(Offset(screenRect.left, screenRect.top));
    final size = screenToDocDelta(Offset(screenRect.width, screenRect.height));
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, size.dx, size.dy);
  }
}
