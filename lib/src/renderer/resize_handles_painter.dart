import 'package:flutter/material.dart';

class ResizeHandlesPainter extends CustomPainter {
  final Rect screenFrame;
  final bool isSelected;
  final double rotation;
  final bool textNodeHandles;

  ResizeHandlesPainter({
    required this.screenFrame,
    required this.isSelected,
    this.rotation = 0,
    this.textNodeHandles = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!isSelected) return;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRect(screenFrame, borderPaint);

    const double handleSize = 8.0;
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    if (textNodeHandles) {
      final sides = [
        Offset(screenFrame.left, screenFrame.center.dy),
        Offset(screenFrame.right, screenFrame.center.dy),
      ];
      for (final side in sides) {
        final rect = Rect.fromCenter(center: side, width: handleSize, height: handleSize);
        canvas.drawRect(rect, handlePaint);
        canvas.drawRect(rect, handleBorderPaint);
      }
    } else {
      final corners = [
        screenFrame.topLeft,
        screenFrame.topRight,
        screenFrame.bottomLeft,
        screenFrame.bottomRight,
      ];

      for (final corner in corners) {
        final rect = Rect.fromCenter(center: corner, width: handleSize, height: handleSize);
        canvas.drawRect(rect, handlePaint);
        canvas.drawRect(rect, handleBorderPaint);
      }
    }

    // Rotation handle: line from top-center to a circle above
    final topCenter = Offset(screenFrame.center.dx, screenFrame.top);
    final rotationHandleCenter = Offset(topCenter.dx, topCenter.dy - 20.0);

    final linePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.5;

    canvas.drawLine(topCenter, rotationHandleCenter, linePaint);

    final rotationHandlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(rotationHandleCenter, 4.0, rotationHandlePaint);
  }

  @override
  bool shouldRepaint(covariant ResizeHandlesPainter oldDelegate) {
    return oldDelegate.screenFrame != screenFrame ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.rotation != rotation ||
        oldDelegate.textNodeHandles != textNodeHandles;
  }
}
