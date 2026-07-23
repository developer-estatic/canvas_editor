import 'package:flutter/material.dart';
import '../document/models/design_document.dart';

/// Registers a custom Node type with JSON + widget builders for Host extensions.
class CustomNodeType<T extends DesignNode> {
  /// Stable type id stored in JSON (`DesignNode.type`).
  final String type;

  /// Deserializes a node map into a [DesignNode] subtype.
  final T Function(Map<String, dynamic> json) fromJson;

  /// Builds the on-canvas widget for this node.
  final Widget Function(BuildContext context, T node) builder;

  const CustomNodeType({
    required this.type,
    required this.fromJson,
    required this.builder,
  });
}

/// Per-Controller registry of [CustomNodeType]s.
///
/// Prefer constructing via [CanvasEditorController.customNodeTypes]. Two
/// Controllers (or tests) each get an isolated registry and cannot clobber
/// each other.
class CustomNodeRegistry {
  final Map<String, CustomNodeType> _registry = {};

  /// Creates a registry, optionally seeding it with [types].
  CustomNodeRegistry([List<CustomNodeType>? types]) {
    if (types != null) {
      for (final type in types) {
        _register(type);
      }
    }
  }

  void _register(CustomNodeType type) {
    _registry[type.type] = type;
  }

  /// Looks up a registered type, or `null`.
  CustomNodeType? resolve(String type) => _registry[type];

  /// All registered custom types.
  List<CustomNodeType> get types => _registry.values.toList();

  /// Process-global registry kept for 1.x migration only.
  static final CustomNodeRegistry _legacyGlobal = CustomNodeRegistry();

  /// Registers a single custom type on the process-global registry.
  ///
  /// Prefer [CanvasEditorController] `customNodeTypes` so registries stay
  /// isolated per Controller.
  @Deprecated(
    'Pass customNodeTypes to CanvasEditorController instead. '
    'Static CustomNodeRegistry mutate APIs will be removed in 2.0.',
  )
  static void register(CustomNodeType type) => _legacyGlobal._register(type);

  /// Looks up a type on the process-global registry.
  @Deprecated(
    'Use a Controller-scoped CustomNodeRegistry (via customNodeTypes / '
    'DesignDocument.fromJson customNodes). Removed in 2.0.',
  )
  static CustomNodeType? get(String type) => _legacyGlobal.resolve(type);

  /// Registers many types on the process-global registry.
  @Deprecated(
    'Pass customNodeTypes to CanvasEditorController instead. '
    'Static CustomNodeRegistry mutate APIs will be removed in 2.0.',
  )
  static void registerAll(List<CustomNodeType> types) {
    for (final type in types) {
      // ignore: deprecated_member_use_from_same_package
      register(type);
    }
  }

  /// All types on the process-global registry.
  @Deprecated('Use a Controller-scoped CustomNodeRegistry. Removed in 2.0.')
  static List<CustomNodeType> get all => _legacyGlobal.types;
}
