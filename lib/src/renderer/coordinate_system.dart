import 'dart:ui';

/// Maps between Design Document coordinates and on-screen viewport coordinates.
///
/// Most Host UI code never needs this — gestures and export use it internally.
/// Useful for custom overlays that must align with document space.
class CoordinateSystem {
  /// Document width in document units.
  final double width;

  /// Document height in document units.
  final double height;

  /// Scale factor from document units to screen pixels.
  final double viewportScale;

  /// Top-left of the document in screen space.
  final Offset viewportOffset;

  CoordinateSystem({
    required this.width,
    required this.height,
    required this.viewportScale,
    required this.viewportOffset,
  });

  /// Converts a point from document space to screen space.
  Offset docToScreen(Offset docPoint) {
    return Offset(
      docPoint.dx * viewportScale + viewportOffset.dx,
      docPoint.dy * viewportScale + viewportOffset.dy,
    );
  }

  /// Converts a delta/size from document space to screen space.
  Offset docToScreenDelta(Offset docDelta) {
    return docDelta * viewportScale;
  }

  /// Converts a point from screen space to document space.
  Offset screenToDoc(Offset screenPoint) {
    return Offset(
      (screenPoint.dx - viewportOffset.dx) / viewportScale,
      (screenPoint.dy - viewportOffset.dy) / viewportScale,
    );
  }

  /// Converts a delta/size from screen space to document space.
  Offset screenToDocDelta(Offset screenDelta) {
    return screenDelta / viewportScale;
  }

  /// Converts a [Rect] from document space to screen space.
  Rect docToScreenRect(Rect docRect) {
    final topLeft = docToScreen(Offset(docRect.left, docRect.top));
    final size = docToScreenDelta(Offset(docRect.width, docRect.height));
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, size.dx, size.dy);
  }

  /// Converts a [Rect] from screen space to document space.
  Rect screenToDocRect(Rect screenRect) {
    final topLeft = screenToDoc(Offset(screenRect.left, screenRect.top));
    final size = screenToDocDelta(Offset(screenRect.width, screenRect.height));
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, size.dx, size.dy);
  }
}
