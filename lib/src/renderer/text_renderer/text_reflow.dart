import 'dart:math' as math;
import 'dart:ui';

import '../../document/models/design_document.dart';
import 'text_measurement_service.dart';

/// Text Reflow and Text Node Resize frame math (Document Space).
class TextReflow {
  static const double minWidth = 20.0;

  /// Re-measures height at the node's current width; keeps top-left fixed.
  static TextNode apply(TextNode node) {
    return node.copyWith(
      frame: _frameAt(
        node: node,
        width: node.frame.width,
        left: node.frame.left,
        top: node.frame.top,
      ),
    );
  }

  /// Frame after a horizontal resize: new [width], measured height, anchor-fixed
  /// top corner (top-left for `mr`, top-right for `ml`), including rotation.
  static Rect resizeFrame({
    required TextNode node,
    required Rect startFrame,
    required String anchor,
    required double width,
  }) {
    final clampedWidth = math.max(minWidth, width);
    final height = _measuredHeight(node, clampedWidth);

    if (node.rotation == 0) {
      if (anchor == 'mr') {
        return Rect.fromLTWH(
          startFrame.left,
          startFrame.top,
          clampedWidth,
          height,
        );
      }
      return Rect.fromLTWH(
        startFrame.right - clampedWidth,
        startFrame.top,
        clampedWidth,
        height,
      );
    }

    final angleRad = node.rotation * math.pi / 180;
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);
    final startCenter = startFrame.center;

    final fixedLocalStart = anchor == 'mr'
        ? Offset(-startFrame.width / 2, -startFrame.height / 2)
        : Offset(startFrame.width / 2, -startFrame.height / 2);

    final fixedDoc = Offset(
      startCenter.dx + fixedLocalStart.dx * cosA - fixedLocalStart.dy * sinA,
      startCenter.dy + fixedLocalStart.dx * sinA + fixedLocalStart.dy * cosA,
    );

    final fixedLocalNew = anchor == 'mr'
        ? Offset(-clampedWidth / 2, -height / 2)
        : Offset(clampedWidth / 2, -height / 2);

    final newCenter = Offset(
      fixedDoc.dx - (fixedLocalNew.dx * cosA - fixedLocalNew.dy * sinA),
      fixedDoc.dy - (fixedLocalNew.dx * sinA + fixedLocalNew.dy * cosA),
    );

    return Rect.fromCenter(
      center: newCenter,
      width: clampedWidth,
      height: height,
    );
  }

  static double _measuredHeight(TextNode node, double width) {
    return TextMeasurementService.measureText(
      text: node.text,
      fontFamily: node.fontFamily,
      fontSize: node.fontSize,
      fontWeight: node.fontWeight,
      lineHeight: node.lineHeight,
      letterSpacing: node.letterSpacing,
      maxWidth: width,
    ).height;
  }

  static Rect _frameAt({
    required TextNode node,
    required double width,
    required double left,
    required double top,
  }) {
    return Rect.fromLTWH(left, top, width, _measuredHeight(node, width));
  }
}
