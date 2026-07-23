import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_canvas_editor/flutter_canvas_editor.dart';

void main() {
  group('encodeDocumentColor / decodeDocumentColor', () {
    test('round-trips opaque and translucent colors', () {
      const samples = [
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0x80FF0000),
        Color(0x12345678),
      ];
      for (final color in samples) {
        final hex = encodeDocumentColor(color);
        expect(hex, matches(RegExp(r'^#[0-9A-F]{8}$')));
        expect(decodeDocumentColor(hex), color);
      }
    });

    test('accepts #RRGGBB with implied opaque alpha', () {
      expect(decodeDocumentColor('#FF0000'), const Color(0xFFFF0000));
      expect(decodeDocumentColor('00FF00'), const Color(0xFF00FF00));
    });

    test('accepts hex without leading #', () {
      expect(decodeDocumentColor('FF112233'), const Color(0xFF112233));
    });

    test('throws FormatException on invalid input', () {
      expect(() => decodeDocumentColor(''), throwsFormatException);
      expect(() => decodeDocumentColor('   '), throwsFormatException);
      expect(() => decodeDocumentColor('#GGG'), throwsFormatException);
      expect(() => decodeDocumentColor('#12345'), throwsFormatException);
      expect(() => decodeDocumentColor('#123456789'), throwsFormatException);
      expect(() => decodeDocumentColor('notahex'), throwsFormatException);
    });
  });
}
