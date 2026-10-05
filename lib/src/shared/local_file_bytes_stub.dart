import 'dart:typed_data';

/// Web and other non-IO targets have no local file system.
Future<Uint8List?> readLocalFileBytes(String path) async => null;
