import 'package:flutter/material.dart';
import '../controller/canvas_editor_controller.dart';
import '../theme/canvas_theme.dart';

/// Zero-chrome embeddable canvas. Host UI wraps this widget and drives it
/// through [controller].
///
/// Built-in gestures: select, drag, resize, rotate, and double-tap text edit.
class CanvasEditorWidget extends StatelessWidget {
  /// Controller that owns the Design Document and history.
  final CanvasEditorController controller;

  /// Optional selection chrome styling. Defaults to [CanvasTheme] blues.
  final CanvasTheme? theme;

  const CanvasEditorWidget({
    super.key,
    required this.controller,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return controller.buildCanvas(theme: theme ?? const CanvasTheme());
  }
}
