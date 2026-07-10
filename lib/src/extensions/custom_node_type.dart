import 'package:flutter/material.dart';
import '../document/models/design_document.dart';

class CustomNodeType<T extends DesignNode> {
  final String type;
  final T Function(Map<String, dynamic> json) fromJson;
  final Widget Function(BuildContext context, T node) builder;

  const CustomNodeType({
    required this.type,
    required this.fromJson,
    required this.builder,
  });
}

class CustomNodeRegistry {
  static final Map<String, CustomNodeType> _registry = {};

  static void register(CustomNodeType type) {
    _registry[type.type] = type;
  }

  static CustomNodeType? get(String type) => _registry[type];

  static void registerAll(List<CustomNodeType> types) {
    for (final type in types) {
      register(type);
    }
  }

  static List<CustomNodeType> get all => _registry.values.toList();
}
