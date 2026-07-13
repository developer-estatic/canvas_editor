import 'dart:ui';
import '../../extensions/custom_node_type.dart';

/// A positioned, selectable item on a [DesignDocument] (text, image, or custom).
///
/// Background Fill is stored as [BackgroundNode] but is not selectable.
abstract class DesignNode {
  final String id;
  final String type;
  final Rect frame;
  final int zIndex;
  final double rotation;
  final double scaleX;
  final double scaleY;

  const DesignNode({
    required this.id,
    required this.type,
    required this.frame,
    required this.zIndex,
    this.rotation = 0,
    this.scaleX = 1,
    this.scaleY = 1,
  });

  DesignNode copyWith({
    Rect? frame,
    int? zIndex,
    double? rotation,
    double? scaleX,
    double? scaleY,
  });

  Map<String, dynamic> toJson();

  Map<String, dynamic> _transformToJson() => {
        'rotation': rotation,
        'scaleX': scaleX,
        'scaleY': scaleY,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesignNode &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          frame == other.frame &&
          zIndex == other.zIndex &&
          rotation == other.rotation &&
          scaleX == other.scaleX &&
          scaleY == other.scaleY;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      frame.hashCode ^
      zIndex.hashCode ^
      rotation.hashCode ^
      scaleX.hashCode ^
      scaleY.hashCode;
}

/// Editable text Node. Default [fontSize] is 48.
class TextNode extends DesignNode {
  final String text;
  final String fontFamily;
  final double fontSize;
  /// Font weight as CSS-style number (e.g. 400, 700).
  final int fontWeight;
  final double lineHeight;
  final double letterSpacing;
  /// ARGB hex, e.g. `'#FF000000'`.
  final String textColor;
  /// `'left'`, `'center'`, or `'right'`.
  final String textAlign;

  const TextNode({
    required super.id,
    required super.frame,
    required super.zIndex,
    super.rotation,
    super.scaleX,
    super.scaleY,
    required this.text,
    this.fontFamily = 'Inter',
    this.fontSize = 48.0,
    this.fontWeight = 400,
    this.lineHeight = 1.2,
    this.letterSpacing = 0.0,
    this.textColor = '#FF000000',
    this.textAlign = 'left',
  }) : super(type: 'text');

  @override
  TextNode copyWith({
    Rect? frame,
    int? zIndex,
    double? rotation,
    double? scaleX,
    double? scaleY,
    String? text,
    String? fontFamily,
    double? fontSize,
    int? fontWeight,
    double? lineHeight,
    double? letterSpacing,
    String? textColor,
    String? textAlign,
  }) {
    return TextNode(
      id: id,
      frame: frame ?? this.frame,
      zIndex: zIndex ?? this.zIndex,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      text: text ?? this.text,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      lineHeight: lineHeight ?? this.lineHeight,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      textColor: textColor ?? this.textColor,
      textAlign: textAlign ?? this.textAlign,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'frame': {
          'x': frame.left,
          'y': frame.top,
          'width': frame.width,
          'height': frame.height,
        },
        'text': text,
        'style': {
          'fontFamily': fontFamily,
          'fontSize': fontSize,
          'fontWeight': fontWeight,
          'lineHeight': lineHeight,
          'letterSpacing': letterSpacing,
          'textColor': textColor,
          'textAlign': textAlign,
        },
        'transform': _transformToJson(),
        'zIndex': zIndex,
      };

  factory TextNode.fromJson(Map<String, dynamic> json) {
    final frameMap = json['frame'] as Map<String, dynamic>;
    final styleMap = json['style'] as Map<String, dynamic>? ?? {};
    final transformMap = json['transform'] as Map<String, dynamic>?;
    return TextNode(
      id: json['id'] as String,
      frame: Rect.fromLTWH(
        (frameMap['x'] as num).toDouble(),
        (frameMap['y'] as num).toDouble(),
        (frameMap['width'] as num).toDouble(),
        (frameMap['height'] as num).toDouble(),
      ),
      zIndex: json['zIndex'] as int? ?? 0,
      rotation: (transformMap?['rotation'] as num? ?? 0).toDouble(),
      scaleX: (transformMap?['scaleX'] as num? ?? 1).toDouble(),
      scaleY: (transformMap?['scaleY'] as num? ?? 1).toDouble(),
      text: json['text'] as String,
      fontFamily: styleMap['fontFamily'] as String? ?? 'Inter',
      fontSize: (styleMap['fontSize'] as num? ?? 48.0).toDouble(),
      fontWeight: styleMap['fontWeight'] as int? ?? 400,
      lineHeight: (styleMap['lineHeight'] as num? ?? 1.2).toDouble(),
      letterSpacing: (styleMap['letterSpacing'] as num? ?? 0.0).toDouble(),
      textColor: styleMap['textColor'] as String? ?? '#FF000000',
      textAlign: styleMap['textAlign'] as String? ?? 'left',
    );
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is TextNode &&
      text == other.text &&
      fontFamily == other.fontFamily &&
      fontSize == other.fontSize &&
      fontWeight == other.fontWeight &&
      lineHeight == other.lineHeight &&
      letterSpacing == other.letterSpacing &&
      textColor == other.textColor &&
      textAlign == other.textAlign;

  @override
  int get hashCode =>
      super.hashCode ^
      text.hashCode ^
      fontFamily.hashCode ^
      fontSize.hashCode ^
      fontWeight.hashCode ^
      lineHeight.hashCode ^
      letterSpacing.hashCode ^
      textColor.hashCode ^
      textAlign.hashCode;
}



/// Image Node backed by a local file and/or Host-resolved [assetId].
class ImageNode extends DesignNode {
  final String? assetId;
  final String? localPath;
  /// Box-fit style: `'cover'`, `'contain'`, or `'fill'`.
  final String fit;

  const ImageNode({
    required super.id,
    required super.frame,
    required super.zIndex,
    super.rotation,
    super.scaleX,
    super.scaleY,
    this.assetId,
    this.localPath,
    this.fit = 'cover',
  }) : super(type: 'image');

  @override
  ImageNode copyWith({
    Rect? frame,
    int? zIndex,
    double? rotation,
    double? scaleX,
    double? scaleY,
    String? assetId,
    String? localPath,
    String? fit,
  }) {
    return ImageNode(
      id: id,
      frame: frame ?? this.frame,
      zIndex: zIndex ?? this.zIndex,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      assetId: assetId ?? this.assetId,
      localPath: localPath ?? this.localPath,
      fit: fit ?? this.fit,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'frame': {
          'x': frame.left,
          'y': frame.top,
          'width': frame.width,
          'height': frame.height,
        },
        'assetId': assetId,
        'localPath': localPath,
        'fit': fit,
        'transform': _transformToJson(),
        'zIndex': zIndex,
      };

  factory ImageNode.fromJson(Map<String, dynamic> json) {
    final frameMap = json['frame'] as Map<String, dynamic>;
    final transformMap = json['transform'] as Map<String, dynamic>?;
    return ImageNode(
      id: json['id'] as String,
      frame: Rect.fromLTWH(
        (frameMap['x'] as num).toDouble(),
        (frameMap['y'] as num).toDouble(),
        (frameMap['width'] as num).toDouble(),
        (frameMap['height'] as num).toDouble(),
      ),
      zIndex: json['zIndex'] as int? ?? 0,
      rotation: (transformMap?['rotation'] as num? ?? 0).toDouble(),
      scaleX: (transformMap?['scaleX'] as num? ?? 1).toDouble(),
      scaleY: (transformMap?['scaleY'] as num? ?? 1).toDouble(),
      assetId: json['assetId'] as String?,
      localPath: json['localPath'] as String?,
      fit: json['fit'] as String? ?? 'cover',
    );
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is ImageNode &&
      assetId == other.assetId &&
      localPath == other.localPath &&
      fit == other.fit;

  @override
  int get hashCode => super.hashCode ^ assetId.hashCode ^ localPath.hashCode ^ fit.hashCode;
}



/// Background Fill stored as a node. Not selectable via hit-testing; use product
/// language "background fill" in Host UI, not "background node".
class BackgroundNode extends DesignNode {
  final String color; // Hex string e.g. '#FFFFFFFF'
  final String? assetId;
  final String? localPath;

  const BackgroundNode({
    required super.id,
    required super.frame,
    required super.zIndex,
    super.rotation,
    super.scaleX,
    super.scaleY,
    required this.color,
    this.assetId,
    this.localPath,
  }) : super(type: 'background');

  bool get hasBackgroundImage =>
      (localPath != null && localPath!.isNotEmpty) ||
      (assetId != null && assetId!.isNotEmpty);

  static const Object _unset = Object();

  @override
  BackgroundNode copyWith({
    Rect? frame,
    int? zIndex,
    double? rotation,
    double? scaleX,
    double? scaleY,
    String? color,
    Object? assetId = _unset,
    Object? localPath = _unset,
  }) {
    return BackgroundNode(
      id: id,
      frame: frame ?? this.frame,
      zIndex: zIndex ?? this.zIndex,
      rotation: rotation ?? this.rotation,
      scaleX: scaleX ?? this.scaleX,
      scaleY: scaleY ?? this.scaleY,
      color: color ?? this.color,
      assetId: assetId == _unset ? this.assetId : assetId as String?,
      localPath: localPath == _unset ? this.localPath : localPath as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'frame': {
          'x': frame.left,
          'y': frame.top,
          'width': frame.width,
          'height': frame.height,
        },
        'color': color,
        if (assetId != null) 'assetId': assetId,
        if (localPath != null) 'localPath': localPath,
        'transform': _transformToJson(),
        'zIndex': zIndex,
      };

  factory BackgroundNode.fromJson(Map<String, dynamic> json) {
    final frameMap = json['frame'] as Map<String, dynamic>;
    final transformMap = json['transform'] as Map<String, dynamic>?;
    return BackgroundNode(
      id: json['id'] as String,
      frame: Rect.fromLTWH(
        (frameMap['x'] as num).toDouble(),
        (frameMap['y'] as num).toDouble(),
        (frameMap['width'] as num).toDouble(),
        (frameMap['height'] as num).toDouble(),
      ),
      zIndex: json['zIndex'] as int? ?? 0,
      rotation: (transformMap?['rotation'] as num? ?? 0).toDouble(),
      scaleX: (transformMap?['scaleX'] as num? ?? 1).toDouble(),
      scaleY: (transformMap?['scaleY'] as num? ?? 1).toDouble(),
      color: json['color'] as String,
      assetId: json['assetId'] as String?,
      localPath: json['localPath'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is BackgroundNode &&
      color == other.color &&
      assetId == other.assetId &&
      localPath == other.localPath;

  @override
  int get hashCode =>
      super.hashCode ^ color.hashCode ^ assetId.hashCode ^ localPath.hashCode;
}



/// Persisted canvas content: size plus ordered [nodes] (JSON-serializable).
class DesignDocument {
  final String id;
  final int version;
  /// Document width in document units.
  final double width;
  /// Document height in document units.
  final double height;
  final List<DesignNode> nodes;

  const DesignDocument({
    required this.id,
    required this.version,
    required this.width,
    required this.height,
    required this.nodes,
  });

  DesignDocument copyWith({
    String? id,
    int? version,
    double? width,
    double? height,
    List<DesignNode>? nodes,
  }) {
    return DesignDocument(
      id: id ?? this.id,
      version: version ?? this.version,
      width: width ?? this.width,
      height: height ?? this.height,
      nodes: nodes ?? this.nodes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'version': version,
        'width': width,
        'height': height,
        'nodes': nodes.map((node) => node.toJson()).toList(),
      };

  factory DesignDocument.fromJson(Map<String, dynamic> json) {
    final nodesJson = json['nodes'] as List<dynamic>? ?? [];
    final nodesList = <DesignNode>[];
    for (final nodeMap in nodesJson) {
      final map = nodeMap as Map<String, dynamic>;
      final type = map['type'] as String;
      if (type == 'text') {
        nodesList.add(TextNode.fromJson(map));
      } else if (type == 'image') {
        nodesList.add(ImageNode.fromJson(map));
      } else if (type == 'background') {
        nodesList.add(BackgroundNode.fromJson(map));
      } else {
        final customType = CustomNodeRegistry.get(type);
        if (customType != null) {
          nodesList.add(customType.fromJson(map));
        }
      }
    }
    return DesignDocument(
      id: json['id'] as String,
      version: json['version'] as int? ?? 1,
      width: (json['width'] as num? ?? 1080.0).toDouble(),
      height: (json['height'] as num? ?? 1080.0).toDouble(),
      nodes: nodesList,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DesignDocument &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          version == other.version &&
          width == other.width &&
          height == other.height &&
          _listEquals(nodes, other.nodes);

  @override
  int get hashCode =>
      id.hashCode ^ version.hashCode ^ width.hashCode ^ height.hashCode ^ nodes.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
