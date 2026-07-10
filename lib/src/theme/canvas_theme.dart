import 'package:flutter/material.dart';

class CanvasTheme {
  final Color handleColor;
  final double handleSize;
  final Color selectionBorderColor;
  final double selectionBorderWidth;
  final Color rotationHandleColor;

  const CanvasTheme({
    this.handleColor = Colors.blue,
    this.handleSize = 8.0,
    this.selectionBorderColor = Colors.blue,
    this.selectionBorderWidth = 1.5,
    this.rotationHandleColor = Colors.blue,
  });
}
