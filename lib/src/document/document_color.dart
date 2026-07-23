import 'dart:ui';

/// Encodes a Flutter [Color] as a Document Color hex string (`#AARRGGBB`).
///
/// Use at the Host UI boundary before calling Controller mutators that store
/// Document Color as hex (e.g. [CanvasEditorController.updateBackground]).
String encodeDocumentColor(Color color) {
  final argb = color.toARGB32();
  return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
}

/// Decodes a Document Color hex string to a Flutter [Color].
///
/// Accepts `#AARRGGBB` or `#RRGGBB` (alpha defaults to `FF`). Leading `#` is
/// optional. Throws [FormatException] when [hex] is empty or not valid hex of
/// length 6 or 8 (after stripping `#`).
Color decodeDocumentColor(String hex) {
  final trimmed = hex.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Document Color hex must not be empty');
  }
  var h = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  if (h.length == 6) {
    h = 'FF$h';
  }
  if (h.length != 8) {
    throw FormatException(
      'Document Color hex must be #RRGGBB or #AARRGGBB, got: $hex',
    );
  }
  final value = int.tryParse(h, radix: 16);
  if (value == null) {
    throw FormatException('Invalid Document Color hex: $hex');
  }
  return Color(value);
}
