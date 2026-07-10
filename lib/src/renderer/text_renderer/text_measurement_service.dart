import 'package:flutter/material.dart';

class TextMeasurementService {
  static const double _minWidth = 30.0;
  static const double _minHeight = 20.0;

  /// Measures the size of a text block given style properties and a maximum width constraint.
  static Size measureText({
    required String text,
    required String fontFamily,
    required double fontSize,
    required int fontWeight,
    required double lineHeight,
    required double letterSpacing,
    required double maxWidth,
  }) {
    if (text.isEmpty) {
      return const Size(_minWidth, _minHeight);
    }

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: _getFontWeight(fontWeight),
        height: lineHeight,
        letterSpacing: letterSpacing,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
      maxLines: null,
    );

    textPainter.layout(maxWidth: maxWidth);

    return Size(
      textPainter.width.clamp(_minWidth, double.infinity),
      textPainter.height.clamp(_minHeight, double.infinity),
    );
  }

  static FontWeight _getFontWeight(int weight) {
    switch (weight) {
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
}
