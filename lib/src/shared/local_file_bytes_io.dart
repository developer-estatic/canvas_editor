import 'dart:io';
import 'dart:typed_data';

/// Reads [path] when a file system is available. Returns null if missing.
Future<Uint8List?> readLocalFileBytes(String path) async {
  try {
    final file = File(path);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  } catch (_) {
    return null;
  }
}
