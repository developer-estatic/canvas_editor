import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';
import '../document/models/design_document.dart';
import '../editor/bloc/editor_bloc.dart';
import '../extensions/custom_node_type.dart';
import '../renderer/coordinate_system.dart';
import '../renderer/text_renderer/text_reflow.dart';
import '../shared/image_load_path.dart';
import '../canvas_editor/canvas_painter.dart';
import 'canvas_editor_state.dart';

class CanvasEditorController {
  final EditorBloc _bloc;
  final CanvasImageProvider? imageProvider;
  final void Function(DesignDocument doc)? onDocumentChanged;
  late final StreamController<CanvasEditorState> _stateStreamController;
  late final StreamSubscription<EditorState> _blocSubscription;

  /// Snapshot captured by [beginHistorySession] for Style History Commit /
  /// gesture-style coalescing. Owned by the engine, not Consumer Chrome.
  DesignDocument? _historySessionSnapshot;

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
    
    // Wire up BLoC updates to the public stream & onDocumentChanged
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
      if (onDocumentChanged != null) {
        onDocumentChanged!(blocState.document);
      }
    });
  }

  // Get current document
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

  // Stream of editor state changes
  Stream<CanvasEditorState> get stateStream => _stateStreamController.stream;

  // Getter for internal BLoC
  EditorBloc get bloc => _bloc;

  // Selection
  void selectNode(String? nodeId) {
    _bloc.add(SelectNodeEvent(nodeId));
  }

  // Node management
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

  void addImageNode({
    required String localPath,
    bool select = true,
  }) {
    _bloc.add(AddImageNodeEvent(localPath, select: select));
  }

  void deleteNode(String nodeId) {
    _bloc.add(DeleteNodeEvent(nodeId));
  }

  // Text styling and editing
  /// Updates Text Node style fields and performs Text Reflow (height fits
  /// text; width held). Pass [recordUndo]: false for mid-session live updates
  /// after [beginHistorySession], then [commitHistorySession] (or a final
  /// call with [recordUndo]: true for a discrete single write).
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

  /// Updates Text Node content and performs Text Reflow (height fits text;
  /// width held). See [updateTextStyle] for [recordUndo] coalescing.
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

  /// Starts a Style History Commit / gesture-style session. Call before a
  /// series of mid-updates with `recordUndo: false`, then [commitHistorySession].
  void beginHistorySession() {
    _historySessionSnapshot = document;
  }

  /// Finishes a history session started by [beginHistorySession], pushing one
  /// undo step when the document changed. Equality is checked inside the
  /// engine after queued updates are applied — do not gate on [document] here
  /// (a pending mid-update may not have been processed yet).
  void commitHistorySession() {
    final snapshot = _historySessionSnapshot;
    _historySessionSnapshot = null;
    if (snapshot == null) return;
    _bloc.add(CommitHistoryEvent(snapshot));
  }

  TextNode _reflowTextNode(TextNode node) => TextReflow.apply(node);

  // Layer ordering
  void bringForward(String nodeId) {
    _bloc.add(LayerReorderEvent(nodeId, LayerReorderAction.bringForward));
  }

  void sendBackward(String nodeId) {
    _bloc.add(LayerReorderEvent(nodeId, LayerReorderAction.sendBackward));
  }

  void bringToFront(String nodeId) {
    _bloc.add(LayerReorderEvent(nodeId, LayerReorderAction.bringToFront));
  }

  void sendToBack(String nodeId) {
    _bloc.add(LayerReorderEvent(nodeId, LayerReorderAction.sendToBack));
  }

  // Background
  void updateBackground(String colorHex, {bool recordUndo = true}) {
    final inSession = _historySessionSnapshot != null;
    if (inSession && recordUndo) {
      _bloc.add(UpdateBackgroundColorEvent(colorHex, recordUndo: false));
      commitHistorySession();
      return;
    }
    _bloc.add(UpdateBackgroundColorEvent(colorHex, recordUndo: recordUndo));
  }

  /// Sets Background Image via [localPath] or [assetId] (exclusive — one clears the other).
  void setBackgroundImage({String? localPath, String? assetId}) {
    _bloc.add(SetBackgroundImageEvent(localPath: localPath, assetId: assetId));
  }

  /// Clears Background Image and restores Dormant Background Color for painting.
  void clearBackgroundImage() {
    _bloc.add(ClearBackgroundImageEvent());
  }

  // History
  void undo() {
    _historySessionSnapshot = null;
    _bloc.add(UndoEvent());
  }

  void redo() {
    _historySessionSnapshot = null;
    _bloc.add(RedoEvent());
  }

  // Document management
  void loadDocument(DesignDocument doc) {
    _bloc.add(LoadDocumentEvent(doc));
  }

  // Export to PNG
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

  // Lifecycle
  void dispose() {
    _blocSubscription.cancel();
    _bloc.close();
    _stateStreamController.close();
  }
}
