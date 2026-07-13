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

/// Global registry of [CustomNodeType]s. Prefer passing types to
/// [CanvasEditorController] via `customNodeTypes` at construction.
class CustomNodeRegistry {
  static final Map<String, CustomNodeType> _registry = {};

  /// Registers a single custom type (overwrites the same [CustomNodeType.type]).
  static void register(CustomNodeType type) {
    _registry[type.type] = type;
  }

  /// Looks up a registered type, or `null`.
  static CustomNodeType? get(String type) => _registry[type];

  /// Registers many types at once.
  static void registerAll(List<CustomNodeType> types) {
    for (final type in types) {
      register(type);
    }
  }

  /// All registered custom types.
  static List<CustomNodeType> get all => _registry.values.toList();
}
