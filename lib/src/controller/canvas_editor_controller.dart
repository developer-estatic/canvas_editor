import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../document/models/design_document.dart';
import '../editor/bloc/editor_bloc.dart';
import '../extensions/custom_node_type.dart';
import '../renderer/coordinate_system.dart';
import '../renderer/text_renderer/text_reflow.dart';
import '../shared/image_load_path.dart';
import '../canvas_editor/canvas_editor.dart';
import '../canvas_editor/canvas_painter.dart';
import '../theme/canvas_theme.dart';
import 'canvas_editor_state.dart';

/// Primary Host API for the Canvas Editor Engine.
///
/// Create one controller, pass it to [CanvasEditorWidget], and build Host UI
/// (toolbars, panels) around [stateStream] / command methods.
///
/// - **Live UI** → listen to [stateStream] (updates every gesture frame).
/// - **Autosave / sync** → [onDocumentChanged] (fires on committed changes only).
class CanvasEditorController {
  final EditorBloc _bloc;

  /// Resolves `assetId` image references (CDN URLs, assets, etc.).
  final CanvasImageProvider? imageProvider;

  /// Called when a Design Document change is committed (gesture end, add/delete,
  /// history session commit, undo/redo, load) — not on every mid-drag frame.
  final void Function(DesignDocument doc)? onDocumentChanged;
  late final StreamController<CanvasEditorState> _stateStreamController;
  late final StreamSubscription<EditorState> _blocSubscription;

  /// Snapshot captured by [beginHistorySession] for Style History Commit /
  /// gesture-style coalescing. Owned by the Engine, not Host UI.
  DesignDocument? _historySessionSnapshot;

  /// Creates a controller.
  ///
  /// If [initialDocument] is omitted, starts with a 1080×1080 white Background Fill.
  CanvasEditorController({
    DesignDocument? initialDocument,
    this.imageProvider,
    List<CustomNodeType>? customNodeTypes,
    this.onDocumentChanged,
  }) : _bloc = EditorBloc(
          initialDocument ??
              const DesignDocument(
                id: 'default_doc',
                version: 1,
                width: 1080,
                height: 1080,
                nodes: [
                  BackgroundNode(
                    id: 'bg_node',
                    frame: Rect.fromLTWH(0, 0, 1080, 1080),
                    zIndex: 0,
                    color: '#FFFFFFFF',
                  ),
                ],
              ),
        ) {
    if (customNodeTypes != null) {
      CustomNodeRegistry.registerAll(customNodeTypes);
    }
    _stateStreamController = StreamController<CanvasEditorState>.broadcast();
    
    // Wire up BLoC updates to the public stream; notify Host only on commits
    // (Slider.onChangeEnd-style), not mid-gesture pan frames.
    _blocSubscription = _bloc.stream.listen((blocState) {
      final selectedNode = blocState.selectedNodeId == null
          ? null
          : blocState.document.nodes.cast<DesignNode?>().firstWhere(
                (n) => n?.id == blocState.selectedNodeId,
                orElse: () => null,
              );
      final newState = CanvasEditorState(
        document: blocState.document,
        selectedNode: selectedNode,
        canUndo: blocState.undoStack.isNotEmpty,
        canRedo: blocState.redoStack.isNotEmpty,
        hasUnsavedChanges: blocState.undoStack.isNotEmpty,
      );
      _stateStreamController.add(newState);
      if (blocState.documentCommitted && onDocumentChanged != null) {
        onDocumentChanged!(blocState.document);
      }
    });
  }

  /// Current Design Document (latest, including mid-gesture previews).
  DesignDocument get document => _bloc.state.document;

  /// Current public editor snapshot (selection, undo flags, document).
  CanvasEditorState get state {
    final blocState = _bloc.state;
    final selectedNode = blocState.selectedNodeId == null
        ? null
        : blocState.document.nodes.cast<DesignNode?>().firstWhere(
              (n) => n?.id == blocState.selectedNodeId,
              orElse: () => null,
            );
    return CanvasEditorState(
      document: blocState.document,
      selectedNode: selectedNode,
      canUndo: blocState.undoStack.isNotEmpty,
      canRedo: blocState.redoStack.isNotEmpty,
      hasUnsavedChanges: blocState.undoStack.isNotEmpty,
    );
  }

  /// Live Engine state for Host UI. Emits on selection and every document mutation,
  /// including mid-drag frames.
  Stream<CanvasEditorState> get stateStream => _stateStreamController.stream;

  /// Used by [CanvasEditorWidget] only — not part of the Host command API.
  ///
  /// @nodoc
  Widget buildCanvas({CanvasTheme theme = const CanvasTheme()}) {
    return BlocProvider<EditorBloc>.value(
      value: _bloc,
      child: CanvasEditor(
        theme: theme,
        imageProvider: imageProvider,
      ),
    );
  }

  /// Selects [nodeId], or clears selection when `null`.
  void selectNode(String? nodeId) {
    _bloc.add(SelectNodeEvent(nodeId));
  }

  /// Adds a text Node. Defaults to centered placeholder text when [text] / [position]
  /// are omitted.
  void addTextNode({
    String? text,
    Offset? position,
    bool select = true,
  }) {
    _bloc.add(AddTextNodeEvent(
      text ?? 'Double tap to edit',
      position ?? Offset(document.width / 2 - 150, document.height / 2 - 50),
      select: select,
    ));
  }

  /// Adds an image Node from a local file path.
  void addImageNode({
    required String localPath,
    bool select = true,
  }) {
    _bloc.add(AddImageNodeEvent(localPath, select: select));
  }

  /// Deletes the Node with [nodeId].
  void deleteNode(String nodeId) {
    _bloc.add(DeleteNodeEvent(nodeId));
  }

  /// Updates text style fields and reflows height to fit wrapped text (width held).
  ///
  /// Pass [recordUndo]: false for mid-session live updates after
  /// [beginHistorySession], then [commitHistorySession].
  void updateTextStyle(
    String nodeId, {
    double? fontSize,
    String? textColor,
    String? fontFamily,
    int? fontWeight,
    double? lineHeight,
    double? letterSpacing,
    String? textAlign,
    bool recordUndo = true,
  }) {
    final node = document.nodes.cast<DesignNode?>().firstWhere(
          (n) => n?.id == nodeId,
          orElse: () => null,
        );
    if (node is TextNode) {
      final styled = node.copyWith(
        fontSize: fontSize,
        textColor: textColor,
        fontFamily: fontFamily,
        fontWeight: fontWeight,
        lineHeight: lineHeight,
        letterSpacing: letterSpacing,
        textAlign: textAlign,
      );
      final updatedNode = _reflowTextNode(styled);
      _applyTextNodeUpdate(updatedNode, recordUndo: recordUndo);
    }
  }

  /// Updates text content and reflows height. See [updateTextStyle] for undo coalescing.
  void updateTextContent(
    String nodeId,
    String text, {
    bool recordUndo = true,
  }) {
    final node = document.nodes.cast<DesignNode?>().firstWhere(
          (n) => n?.id == nodeId,
          orElse: () => null,
        );
    if (node is TextNode) {
      final updatedNode = _reflowTextNode(node.copyWith(text: text));
      _applyTextNodeUpdate(updatedNode, recordUndo: recordUndo);
    }
  }

  /// Applies a Text Node write. When a history session is open and
  /// [recordUndo] is true, mid-state is discarded and one Style History
  /// Commit is taken from the session snapshot (coalesced finish).
  void _applyTextNodeUpdate(TextNode updatedNode, {required bool recordUndo}) {
    final inSession = _historySessionSnapshot != null;
    if (inSession && recordUndo) {
      _bloc.add(UpdateNodeEvent(updatedNode, recordUndo: false));
      commitHistorySession();
      return;
    }
    _bloc.add(UpdateNodeEvent(updatedNode, recordUndo: recordUndo));
  }

  /// Starts a history session so many live property updates become one undo step.
  ///
  /// Call before mid-updates with `recordUndo: false`, then [commitHistorySession].
  void beginHistorySession() {
    _historySessionSnapshot = document;
  }

  /// Ends a [beginHistorySession] and pushes one undo entry when the document changed.
  void commitHistorySession() {
    final snapshot = _historySessionSnapshot;
    _historySessionSnapshot = null;
    if (snapshot == null) return;
    _bloc.add(CommitHistoryEvent(snapshot));
  }

  TextNode _reflowTextNode(TextNode node) => TextReflow.apply(node);

  /// Moves [nodeId] one step up in z-order.
  void bringForward(String nodeId) {
    _bloc.add(LayerReorderEvent(nodeId, LayerReorderAction.bringForward));
  }

  /// Moves [nodeId] one step down in z-order.
  void sendBackward(String nodeId) {
    _bloc.add(LayerReorderEvent(nodeId, LayerReorderAction.sendBackward));
  }

  /// Moves [nodeId] above all other Nodes.
  void bringToFront(String nodeId) {
    _bloc.add(LayerReorderEvent(nodeId, LayerReorderAction.bringToFront));
  }

  /// Moves [nodeId] below all other Nodes (above Background Fill).
  void sendToBack(String nodeId) {
    _bloc.add(LayerReorderEvent(nodeId, LayerReorderAction.sendToBack));
  }

  /// Sets Background Fill to a solid ARGB hex color (e.g. `'#FFFFFFFF'`).
  void updateBackground(String colorHex, {bool recordUndo = true}) {
    final inSession = _historySessionSnapshot != null;
    if (inSession && recordUndo) {
      _bloc.add(UpdateBackgroundColorEvent(colorHex, recordUndo: false));
      commitHistorySession();
      return;
    }
    _bloc.add(UpdateBackgroundColorEvent(colorHex, recordUndo: recordUndo));
  }

  /// Sets Background Fill image. Pass either [localPath] or [assetId], not both.
  void setBackgroundImage({String? localPath, String? assetId}) {
    _bloc.add(SetBackgroundImageEvent(localPath: localPath, assetId: assetId));
  }

  /// Clears Background Fill image and restores the solid color.
  void clearBackgroundImage() {
    _bloc.add(ClearBackgroundImageEvent());
  }

  /// Undoes the last committed change.
  void undo() {
    _historySessionSnapshot = null;
    _bloc.add(UndoEvent());
  }

  /// Redoes the last undone change.
  void redo() {
    _historySessionSnapshot = null;
    _bloc.add(RedoEvent());
  }

  /// Replaces the current Design Document.
  void loadDocument(DesignDocument doc) {
    _historySessionSnapshot = null;
    _bloc.add(LoadDocumentEvent(doc));
  }

  /// Renders the current Design Document to PNG bytes (same pipeline as the live canvas).
  Future<Uint8List> exportToPng({double pixelRatio = 2.0}) async {
    final width = (document.width * pixelRatio).toInt();
    final height = (document.height * pixelRatio).toInt();
    
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final coords = CoordinateSystem(
      width: document.width,
      height: document.height,
      viewportScale: pixelRatio,
      viewportOffset: Offset.zero,
    );
    
    // Load images via Image Load Path (localPath, then imageProvider for Asset Id)
    final cachedImages = await CanvasImageLoader.buildCacheForDocument(
      document: document,
      imageProvider: imageProvider,
    );
    
    final painter = CanvasPainter(
      document: document,
      coords: coords,
      imageCache: cachedImages,
    );
    
    painter.paint(canvas, Size(width.toDouble(), height.toDouble()));
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    // Clean up images
    for (final image in cachedImages.values) {
      image.dispose();
    }
    img.dispose();
    picture.dispose();
    
    if (byteData == null) {
      throw Exception('Failed to generate PNG byte data');
    }
    return byteData.buffer.asUint8List();
  }

  /// Releases streams and internal Engine resources. Call from Host `dispose`.
  void dispose() {
    _blocSubscription.cancel();
    _bloc.close();
    _stateStreamController.close();
  }
}
