import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../document/models/design_document.dart';

class CanvasRenderer {
  /// Renders the design document to an offscreen image matching the exact document dimension size
  static Future<ui.Image> renderToImage(DesignDocument doc) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw nodes
    // Sort by zIndex to ensure correct ordering
    final sortedNodes = List<DesignNode>.from(doc.nodes)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    for (final node in sortedNodes) {
      canvas.save();
      // Clip to document bounds (hard clipping)
      canvas.clipRect(Rect.fromLTWH(0, 0, doc.width, doc.height));

      // Apply transform (pivot at frame center)
      final cx = node.frame.center.dx;
      final cy = node.frame.center.dy;
      canvas.translate(cx, cy);
      canvas.rotate(node.rotation * (3.141592653589793 / 180));
      canvas.scale(node.scaleX, node.scaleY);
      canvas.translate(-cx, -cy);

      if (node is BackgroundNode) {
        final paint = Paint()..color = _parseHexColor(node.color);
        canvas.drawRect(node.frame, paint);
      } else if (node is TextNode) {
        final textSpan = TextSpan(
          text: node.text,
          style: TextStyle(
            color: _parseHexColor(node.textColor),
            fontFamily: node.fontFamily,
            fontSize: node.fontSize,
            fontWeight: _getFontWeight(node.fontWeight),
            height: node.lineHeight,
            letterSpacing: node.letterSpacing,
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
          textAlign: _getTextAlign(node.textAlign),
        );
        textPainter.layout(maxWidth: node.frame.width);
        textPainter.paint(canvas, Offset(node.frame.left, node.frame.top));
      } else if (node is ImageNode) {
        if (node.localPath != null && node.localPath!.isNotEmpty) {
          final file = File(node.localPath!);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final codec = await ui.instantiateImageCodec(bytes);
            final frame = await codec.getNextFrame();
            final uiImage = frame.image;

            _drawImage(canvas, uiImage, node.frame, node.fit);
          }
        } else {
          // If no image is provided, draw a simple placeholder
          final paint = Paint()
            ..color = Colors.grey.shade400
            ..style = PaintingStyle.fill;
          canvas.drawRect(node.frame, paint);

          final borderPaint = Paint()
            ..color = Colors.grey.shade600
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0;
          canvas.drawRect(node.frame, borderPaint);
        }
      }

      canvas.restore();
    }

    final picture = recorder.endRecording();
    return picture.toImage(doc.width.toInt(), doc.height.toInt());
  }

  static void _drawImage(Canvas canvas, ui.Image image, Rect destRect, String fit) {
    final srcSize = Size(image.width.toDouble(), image.height.toDouble());
    final destSize = destRect.size;

    // Calculate source rect based on fit strategy
    Rect srcRect;
    if (fit == 'cover') {
      final double imageAspect = srcSize.width / srcSize.height;
      final double destAspect = destSize.width / destSize.height;
      if (imageAspect > destAspect) {
        // Image is wider than destination
        final double srcWidth = srcSize.height * destAspect;
        final double left = (srcSize.width - srcWidth) / 2;
        srcRect = Rect.fromLTWH(left, 0, srcWidth, srcSize.height);
      } else {
        // Image is taller than destination
        final double srcHeight = srcSize.width / destAspect;
        final double top = (srcSize.height - srcHeight) / 2;
        srcRect = Rect.fromLTWH(0, top, srcSize.width, srcHeight);
      }
    } else if (fit == 'contain') {
      srcRect = Rect.fromLTWH(0, 0, srcSize.width, srcSize.height);
      // For simplicity, we stretch container bounds inside the destination rect
    } else {
      // fill
      srcRect = Rect.fromLTWH(0, 0, srcSize.width, srcSize.height);
    }

    canvas.drawImageRect(
      image,
      srcRect,
      destRect,
      Paint()..isAntiAlias = true,
    );
  }

  static Color _parseHexColor(String hex) {
    String formatted = hex.replaceAll('#', '');
    if (formatted.length == 6) {
      formatted = 'FF$formatted';
    }
    return Color(int.parse(formatted, radix: 16));
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

  static TextAlign _getTextAlign(String align) {
    switch (align) {
      case 'center':
        return TextAlign.center;
      case 'right':
        return TextAlign.right;
      case 'left':
      default:
        return TextAlign.left;
    }
  }
}
