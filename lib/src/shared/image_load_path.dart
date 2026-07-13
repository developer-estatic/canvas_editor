import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../document/models/design_document.dart';

/// Portable image reference: local file path and/or Host [assetId].
class CanvasImageReference {
  const CanvasImageReference({this.localPath, this.assetId});

  /// Absolute or app-relative file path. Preferred over [assetId] when both set.
  final String? localPath;

  /// Host-defined id (URL, asset key, etc.) resolved via [CanvasImageProvider].
  final String? assetId;

  bool get isEmpty =>
      (localPath == null || localPath!.isEmpty) &&
      (assetId == null || assetId!.isEmpty);

  /// Cache key preferring [localPath] over [assetId].
  String? get cacheKey {
    if (localPath != null && localPath!.isNotEmpty) return 'path:$localPath';
    if (assetId != null && assetId!.isNotEmpty) return 'asset:$assetId';
    return null;
  }

  factory CanvasImageReference.fromImageNode(ImageNode node) {
    return CanvasImageReference(
      localPath: node.localPath,
      assetId: node.assetId,
    );
  }

  factory CanvasImageReference.fromBackgroundNode(BackgroundNode node) {
    return CanvasImageReference(
      localPath: node.localPath,
      assetId: node.assetId,
    );
  }
}

/// Host callback that maps an `assetId` reference to an [ImageProvider].
typedef CanvasImageProvider = ImageProvider Function(CanvasImageReference ref);

/// Resolves image pixels for the live canvas and PNG export.
///
/// Prefers [CanvasImageReference.localPath], then [CanvasImageProvider] for
/// [CanvasImageReference.assetId].
abstract final class CanvasImageLoader {
  /// Loads a single image, or `null` if it cannot be resolved.
  static Future<ui.Image?> resolveToUiImage({
    required CanvasImageReference ref,
    CanvasImageProvider? imageProvider,
  }) async {
    if (ref.localPath != null && ref.localPath!.isNotEmpty) {
      try {
        final file = File(ref.localPath!);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          return frame.image;
        }
      } catch (_) {
        // fall through to asset provider
      }
    }

    if (ref.assetId == null ||
        ref.assetId!.isEmpty ||
        imageProvider == null) {
      return null;
    }

    try {
      final provider = imageProvider(ref);
      final stream = provider.resolve(const ImageConfiguration());
      final completer = Completer<ui.Image?>();
      late ImageStreamListener listener;
      listener = ImageStreamListener(
        (info, _) {
          stream.removeListener(listener);
          completer.complete(info.image);
        },
        onError: (_, __) {
          stream.removeListener(listener);
          completer.complete(null);
        },
      );
      stream.addListener(listener);
      return completer.future;
    } catch (_) {
      return null;
    }
  }

  /// Preloads all image references found on [document] into a cache map.
  static Future<Map<String, ui.Image>> buildCacheForDocument({
    required DesignDocument document,
    CanvasImageProvider? imageProvider,
  }) async {
    final cache = <String, ui.Image>{};
    final refs = <CanvasImageReference>[];

    for (final node in document.nodes) {
      if (node is ImageNode && !CanvasImageReference.fromImageNode(node).isEmpty) {
        refs.add(CanvasImageReference.fromImageNode(node));
      } else if (node is BackgroundNode && node.hasBackgroundImage) {
        refs.add(CanvasImageReference.fromBackgroundNode(node));
      }
    }

    for (final ref in refs) {
      final key = ref.cacheKey;
      if (key == null || cache.containsKey(key)) continue;
      final image = await resolveToUiImage(
        ref: ref,
        imageProvider: imageProvider,
      );
      if (image != null) {
        cache[key] = image;
      }
    }

    return cache;
  }
}
