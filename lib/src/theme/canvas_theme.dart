import 'package:flutter/material.dart';

/// Selection chrome for [CanvasEditorWidget] (borders, resize handles, rotation stem).
class CanvasTheme {
  /// Stroke color for corner / side resize handles.
  final Color handleColor;

  /// Square handle edge length in logical pixels.
  final double handleSize;

  /// Selected node bounding-box border color.
  final Color selectionBorderColor;

  /// Selected node border stroke width.
  final double selectionBorderWidth;

  /// Rotation stem color. When null, uses [selectionBorderColor].
  final Color? rotationHandleColor;

  const CanvasTheme({
    this.handleColor = Colors.blue,
    this.handleSize = 8.0,
    this.selectionBorderColor = Colors.blue,
    this.selectionBorderWidth = 1.5,
    this.rotationHandleColor,
  });

  /// Resolved stem color after applying the [rotationHandleColor] fallback.
  Color get effectiveRotationHandleColor =>
      rotationHandleColor ?? selectionBorderColor;
}
