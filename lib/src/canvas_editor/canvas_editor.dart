import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../document/document_color.dart';
import '../document/models/design_document.dart';
import '../editor/bloc/editor_bloc.dart';
import '../renderer/coordinate_system.dart';
import '../theme/canvas_theme.dart';
import '../extensions/custom_node_type.dart';
import '../shared/image_load_path.dart';
import '../renderer/text_renderer/text_reflow.dart';
import 'canvas_painter.dart';

class CanvasEditor extends StatefulWidget {
  final CanvasTheme theme;
  final CanvasImageProvider? imageProvider;
  final CustomNodeRegistry customNodes;

  CanvasEditor({
    super.key,
    this.theme = const CanvasTheme(),
    this.imageProvider,
    CustomNodeRegistry? customNodes,
  }) : customNodes = customNodes ?? CustomNodeRegistry();

  @override
  State<CanvasEditor> createState() => _CanvasEditorState();
}

class _CanvasEditorState extends State<CanvasEditor> {
  final Map<String, ui.Image> _imageCache = {};
  final Set<String> _loadingImages = {};

  // Interaction state
  bool _isDragging = false;
  bool _isResizing = false;
  bool _isRotating = false;
  String? _resizeAnchor;
  Offset? _interactionStartDoc;
  Rect? _startFrame;
  double? _startRotation;
  String? _textEditingNodeId;
  final _textController = TextEditingController();
  final _textFocusNode = FocusNode();

  /// Document snapshot taken at gesture start for a single undo step.
  DesignDocument? _gestureUndoSnapshot;

  void _stopTextEditing() {
    if (_textEditingNodeId == null) return;
    final snapshot = _gestureUndoSnapshot;
    if (snapshot != null) {
      final bloc = context.read<EditorBloc>();
      if (snapshot != bloc.state.document) {
        bloc.add(CommitHistoryEvent(snapshot));
      }
    }
    _textFocusNode.unfocus();
    setState(() {
      _textEditingNodeId = null;
      _gestureUndoSnapshot = null;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    for (final image in _imageCache.values) {
      image.dispose();
    }
    super.dispose();
  }

  void _loadImageReference(CanvasImageReference ref) {
    final key = ref.cacheKey;
    if (key == null ||
        _imageCache.containsKey(key) ||
        _loadingImages.contains(key)) {
      return;
    }
    _loadingImages.add(key);
    CanvasImageLoader.resolveToUiImage(
      ref: ref,
      imageProvider: widget.imageProvider,
    ).then((image) {
      if (!mounted) return;
      setState(() {
        _loadingImages.remove(key);
        if (image != null) {
          _imageCache[key] = image;
        }
      });
    });
  }

  void _preloadDocumentImages(DesignDocument doc) {
    for (final node in doc.nodes) {
      if (node is ImageNode) {
        final ref = CanvasImageReference.fromImageNode(node);
        if (!ref.isEmpty) _loadImageReference(ref);
      } else if (node is BackgroundNode && node.hasBackgroundImage) {
        _loadImageReference(CanvasImageReference.fromBackgroundNode(node));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.watch<EditorBloc>();
    final state = bloc.state;
    final doc = state.document;

    return LayoutBuilder(
      builder: (context, constraints) {
        final scaleX = (constraints.maxWidth - 40) / doc.width;
        final scaleY = (constraints.maxHeight - 40) / doc.height;
        final autoScale = scaleX < scaleY ? scaleX : scaleY;
        final viewW = doc.width * autoScale;
        final viewH = doc.height * autoScale;
        final offset = Offset(
          (constraints.maxWidth - viewW) / 2,
          (constraints.maxHeight - viewH) / 2,
        );

        final coords = CoordinateSystem(
          width: doc.width,
          height: doc.height,
          viewportScale: autoScale,
          viewportOffset: offset,
        );

        // Preload images via Image Load Path
        _preloadDocumentImages(doc);

        return Stack(
          children: [
            GestureDetector(
              onTapUp: (details) => _handleTap(details, bloc, coords),
              onPanStart: (details) =>
                  _handlePanStart(details, bloc, coords, state),
              onPanUpdate: (details) => _handlePanUpdate(details, bloc, coords),
              onPanEnd: (_) => _handlePanEnd(bloc),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: CustomPaint(
                    painter: CanvasPainter(
                      document: doc,
                      coords: coords,
                      selectedNodeId: state.selectedNodeId,
                      imageCache: _imageCache,
                      theme: widget.theme,
                      devicePixelRatio: MediaQuery.devicePixelRatioOf(context),
                      editingNodeId: _textEditingNodeId,
                    ),
                    size: Size(constraints.maxWidth, constraints.maxHeight),
                  ),
                ),
              ),
            ),

            // Render Custom nodes here as widgets
            for (final node in doc.nodes)
              if (node is! TextNode &&
                  node is! ImageNode &&
                  node is! BackgroundNode)
                _buildCustomNodeWidget(context, node, coords),

            // Text editing overlay
            if (_textEditingNodeId != null)
              _buildTextOverlay(bloc, coords, state),
          ],
        );
      },
    );
  }

  Widget _buildCustomNodeWidget(
    BuildContext context,
    DesignNode node,
    CoordinateSystem coords,
  ) {
    final customType = widget.customNodes.resolve(node.type);
    if (customType == null) return const SizedBox.shrink();

    final screenRect = coords.docToScreenRect(node.frame);

    return Positioned.fromRect(
      rect: screenRect,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(node.rotation * (math.pi / 180))
          ..multiply(Matrix4.diagonal3Values(node.scaleX, node.scaleY, 1)),
        child: IgnorePointer(child: customType.builder(context, node)),
      ),
    );
  }

  Widget _buildTextOverlay(
    EditorBloc bloc,
    CoordinateSystem coords,
    EditorState state,
  ) {
    TextNode? node;
    for (final n in state.document.nodes) {
      if (n.id == _textEditingNodeId && n is TextNode) {
        node = n;
        break;
      }
    }
    if (node == null) return const SizedBox.shrink();
    final textNode = node;

    final screenRect = coords.docToScreenRect(textNode.frame);
    final color = _parseHex(textNode.textColor);
    // Same metrics as [CanvasPainter]. TextField otherwise merges the host
    // theme (font, height, letter spacing) and a forced strut, so the caret
    // text sits beside the painted glyphs.
    final style = TextStyle(
      inherit: false,
      textBaseline: TextBaseline.alphabetic,
      color: color,
      fontFamily: textNode.fontFamily,
      fontSize: textNode.fontSize * coords.viewportScale,
      fontWeight: _fontWeight(textNode.fontWeight),
      height: textNode.lineHeight,
      letterSpacing: textNode.letterSpacing * coords.viewportScale,
    );
    final theme = Theme.of(context);

    return Positioned(
      left: screenRect.left,
      top: screenRect.top,
      width: screenRect.width,
      height: screenRect.height,
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..rotateZ(textNode.rotation * (math.pi / 180))
          ..multiply(
            Matrix4.diagonal3Values(textNode.scaleX, textNode.scaleY, 1),
          ),
        child: Theme(
          data: theme.copyWith(
            textTheme: theme.textTheme.copyWith(
              bodyLarge: style,
              titleMedium: style,
            ),
          ),
          child: TextField(
            controller: _textController,
            focusNode: _textFocusNode,
            autofocus: true,
            maxLines: null,
            textInputAction: TextInputAction.done,
            textAlignVertical: TextAlignVertical.top,
            scrollPadding: EdgeInsets.zero,
            cursorWidth: 1.5,
            cursorColor: color,
            strutStyle: StrutStyle.disabled,
            style: style,
            textAlign: _textAlign(textNode.textAlign),
            decoration: const InputDecoration.collapsed(hintText: ''),
            onChanged: (value) {
              bloc.add(
                UpdateNodeTextEvent(textNode.id, value, recordUndo: false),
              );
            },
            onSubmitted: (_) => _stopTextEditing(),
          ),
        ),
      ),
    );
  }

  void _handleTap(
    TapUpDetails details,
    EditorBloc bloc,
    CoordinateSystem coords,
  ) {
    // Tap outside the TextField dismisses inline editing.
    if (_textEditingNodeId != null) {
      _stopTextEditing();
      return;
    }

    final state = bloc.state;
    final doc = state.document;
    final screenPt =
        details.globalPosition -
        (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero);

    // Check if tap is on a selected node's rotation handle
    if (state.selectedNodeId != null) {
      final node = doc.nodes.firstWhere((n) => n.id == state.selectedNodeId);
      if (CanvasHitTest.hitTestRotationHandle(screenPt, node, coords)) {
        return; // will be handled by pan
      }
    }

    // Check resize handles (side for Text Node, corners for others)
    if (state.selectedNodeId != null) {
      final node = doc.nodes.firstWhere((n) => n.id == state.selectedNodeId);
      final anchor = CanvasHitTest.hitTestResizeHandle(screenPt, node, coords);
      if (anchor != null) return; // will be handled by pan
    }

    // Hit test nodes
    final hitNode = CanvasHitTest.hitTestNode(screenPt, doc, coords);
    if (hitNode != null) {
      if (hitNode.id == state.selectedNodeId && hitNode is TextNode) {
        // Double-tap-ish: start editing text
        setState(() {
          _textEditingNodeId = hitNode.id;
          _textController.text = hitNode.text;
          _gestureUndoSnapshot = state.document;
        });
      } else {
        bloc.add(SelectNodeEvent(hitNode.id));
      }
    } else {
      bloc.add(SelectNodeEvent(null));
    }
  }

  void _handlePanStart(
    DragStartDetails details,
    EditorBloc bloc,
    CoordinateSystem coords,
    EditorState state,
  ) {
    // Ensure a clean interaction state for each new gesture
    _isDragging = false;
    _isResizing = false;
    _isRotating = false;
    _resizeAnchor = null;
    _interactionStartDoc = null;
    _startFrame = null;
    _startRotation = null;

    if (_textEditingNodeId != null) {
      _stopTextEditing();
      return;
    }

    final doc = state.document;
    final renderBox = context.findRenderObject() as RenderBox;
    final screenPt =
        details.globalPosition - renderBox.localToGlobal(Offset.zero);

    final selectedNodeId = state.selectedNodeId;
    if (selectedNodeId == null) {
      final hit = CanvasHitTest.hitTestNode(screenPt, doc, coords);
      if (hit != null) {
        bloc.add(SelectNodeEvent(hit.id));
      }
      return;
    }

    final node = doc.nodes.firstWhere((n) => n.id == selectedNodeId);

    // Check rotation handle
    if (CanvasHitTest.hitTestRotationHandle(screenPt, node, coords)) {
      _isRotating = true;
      _interactionStartDoc = coords.screenToDoc(screenPt);
      _startRotation = node.rotation;
      _gestureUndoSnapshot = state.document;
      return;
    }

    // Check resize handles (side for Text Node, corners for others)
    final anchor = CanvasHitTest.hitTestResizeHandle(screenPt, node, coords);
    if (anchor != null) {
      _isResizing = true;
      _resizeAnchor = anchor;
      _interactionStartDoc = coords.screenToDoc(screenPt);
      _startFrame = node.frame;
      _gestureUndoSnapshot = state.document;
      return;
    }

    // Default: drag node
    _isDragging = true;
    _interactionStartDoc = coords.screenToDoc(screenPt);
    _startFrame = node.frame;
    _gestureUndoSnapshot = state.document;
  }

  void _handlePanUpdate(
    DragUpdateDetails details,
    EditorBloc bloc,
    CoordinateSystem coords,
  ) {
    if (_textEditingNodeId != null) return;

    if (_isRotating) {
      _handleRotate(details, bloc, coords);
    } else if (_isResizing) {
      if (_resizeAnchor == 'ml' || _resizeAnchor == 'mr') {
        _handleTextResize(details, bloc, coords);
      } else {
        _handleResize(details, bloc, coords);
      }
    } else if (_isDragging) {
      _handleDrag(details, bloc, coords);
    }
  }

  void _handlePanEnd(EditorBloc bloc) {
    final snapshot = _gestureUndoSnapshot;
    if (snapshot != null && snapshot != bloc.state.document) {
      bloc.add(CommitHistoryEvent(snapshot));
    }

    _isDragging = false;
    _isResizing = false;
    _isRotating = false;
    // Reset interaction helpers
    _resizeAnchor = null;
    _interactionStartDoc = null;
    _startFrame = null;
    _startRotation = null;
    _gestureUndoSnapshot = null;
  }

  void _handleDrag(
    DragUpdateDetails details,
    EditorBloc bloc,
    CoordinateSystem coords,
  ) {
    final state = bloc.state;
    final selectedId = state.selectedNodeId;
    if (selectedId == null ||
        _startFrame == null ||
        _interactionStartDoc == null) {
      return;
    }

    final renderBox = context.findRenderObject() as RenderBox;
    final screenPt =
        details.globalPosition - renderBox.localToGlobal(Offset.zero);
    final docPt = coords.screenToDoc(screenPt);
    final docDelta = docPt - _interactionStartDoc!;

    final double rawLeft = _startFrame!.left + docDelta.dx;
    final double rawTop = _startFrame!.top + docDelta.dy;

    // Clamp so at most half the node can be outside the canvas bounds
    final double minLeft = -_startFrame!.width / 2;
    final double maxLeft = state.document.width - _startFrame!.width / 2;
    final double minTop = -_startFrame!.height / 2;
    final double maxTop = state.document.height - _startFrame!.height / 2;

    final double clampedLeft = rawLeft.clamp(minLeft, maxLeft);
    final double clampedTop = rawTop.clamp(minTop, maxTop);

    bloc.add(
      UpdateNodeFrameEvent(
        selectedId,
        Rect.fromLTWH(
          clampedLeft,
          clampedTop,
          _startFrame!.width,
          _startFrame!.height,
        ),
        recordUndo: false,
      ),
    );
  }

  void _handleTextResize(
    DragUpdateDetails details,
    EditorBloc bloc,
    CoordinateSystem coords,
  ) {
    final state = bloc.state;
    if (state.selectedNodeId == null ||
        _resizeAnchor == null ||
        _startFrame == null ||
        _interactionStartDoc == null) {
      return;
    }

    final node = state.document.nodes.firstWhere(
      (n) => n.id == state.selectedNodeId,
    );
    if (node is! TextNode) return;

    final renderBox = context.findRenderObject() as RenderBox;
    final screenPt =
        details.globalPosition - renderBox.localToGlobal(Offset.zero);
    final docPt = coords.screenToDoc(screenPt);

    final frame = _startFrame!;
    final angleRad = node.rotation * (math.pi / 180);
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);

    final worldDelta = docPt - _interactionStartDoc!;
    final localDelta = Offset(
      worldDelta.dx * cosA + worldDelta.dy * sinA,
      -worldDelta.dx * sinA + worldDelta.dy * cosA,
    );

    final width = switch (_resizeAnchor!) {
      'mr' => frame.width + localDelta.dx,
      'ml' => frame.width - localDelta.dx,
      _ => frame.width,
    };

    final newFrame = TextReflow.resizeFrame(
      node: node,
      startFrame: frame,
      anchor: _resizeAnchor!,
      width: width,
    );

    bloc.add(UpdateNodeFrameEvent(node.id, newFrame, recordUndo: false));
  }

  void _handleResize(
    DragUpdateDetails details,
    EditorBloc bloc,
    CoordinateSystem coords,
  ) {
    final state = bloc.state;
    if (state.selectedNodeId == null ||
        _resizeAnchor == null ||
        _startFrame == null ||
        _interactionStartDoc == null) {
      return;
    }

    final node = state.document.nodes.firstWhere(
      (n) => n.id == state.selectedNodeId,
    );
    final renderBox = context.findRenderObject() as RenderBox;
    final screenPt =
        details.globalPosition - renderBox.localToGlobal(Offset.zero);
    final docPt = coords.screenToDoc(screenPt);

    final frame = _startFrame!;
    const minSize = 20.0;
    final angleRad = node.rotation * (math.pi / 180);
    final cosA = math.cos(angleRad);
    final sinA = math.sin(angleRad);

    // Finger delta from gesture start, in the node's local axes
    final worldDelta = docPt - _interactionStartDoc!;
    final localDelta = Offset(
      worldDelta.dx * cosA + worldDelta.dy * sinA,
      -worldDelta.dx * sinA + worldDelta.dy * cosA,
    );

    double left = frame.left;
    double top = frame.top;
    double width = frame.width;
    double height = frame.height;

    switch (_resizeAnchor!) {
      case 'br':
        width = math.max(minSize, frame.width + localDelta.dx);
        height = math.max(minSize, frame.height + localDelta.dy);
      case 'bl':
        width = math.max(minSize, frame.width - localDelta.dx);
        height = math.max(minSize, frame.height + localDelta.dy);
        left = frame.right - width;
      case 'tr':
        width = math.max(minSize, frame.width + localDelta.dx);
        height = math.max(minSize, frame.height - localDelta.dy);
        top = frame.bottom - height;
      case 'tl':
        width = math.max(minSize, frame.width - localDelta.dx);
        height = math.max(minSize, frame.height - localDelta.dy);
        left = frame.right - width;
        top = frame.bottom - height;
    }

    // Keep the opposite corner fixed under rotation by rebasing the center
    // from the start-frame fixed corner and the new size.
    if (node.rotation != 0) {
      final startCenter = frame.center;
      late final Offset fixedLocalStart;
      late final Offset fixedLocalNew;
      switch (_resizeAnchor!) {
        case 'tl': // opposite = br
          fixedLocalStart = Offset(frame.width / 2, frame.height / 2);
          fixedLocalNew = Offset(width / 2, height / 2);
        case 'tr': // opposite = bl
          fixedLocalStart = Offset(-frame.width / 2, frame.height / 2);
          fixedLocalNew = Offset(-width / 2, height / 2);
        case 'bl': // opposite = tr
          fixedLocalStart = Offset(frame.width / 2, -frame.height / 2);
          fixedLocalNew = Offset(width / 2, -height / 2);
        case 'br': // opposite = tl
          fixedLocalStart = Offset(-frame.width / 2, -frame.height / 2);
          fixedLocalNew = Offset(-width / 2, -height / 2);
      }
      final fixedDoc = Offset(
        startCenter.dx + fixedLocalStart.dx * cosA - fixedLocalStart.dy * sinA,
        startCenter.dy + fixedLocalStart.dx * sinA + fixedLocalStart.dy * cosA,
      );
      final newCenter = Offset(
        fixedDoc.dx - (fixedLocalNew.dx * cosA - fixedLocalNew.dy * sinA),
        fixedDoc.dy - (fixedLocalNew.dx * sinA + fixedLocalNew.dy * cosA),
      );
      left = newCenter.dx - width / 2;
      top = newCenter.dy - height / 2;
    }

    bloc.add(
      UpdateNodeFrameEvent(
        node.id,
        Rect.fromLTWH(left, top, width, height),
        recordUndo: false,
      ),
    );
  }

  void _handleRotate(
    DragUpdateDetails details,
    EditorBloc bloc,
    CoordinateSystem coords,
  ) {
    final state = bloc.state;
    if (state.selectedNodeId == null ||
        _interactionStartDoc == null ||
        _startRotation == null) {
      return;
    }

    final node = state.document.nodes.firstWhere(
      (n) => n.id == state.selectedNodeId,
    );
    final renderBox = context.findRenderObject() as RenderBox;
    final screenPt =
        details.globalPosition - renderBox.localToGlobal(Offset.zero);
    final docPt = coords.screenToDoc(screenPt);
    final center = node.frame.center;

    final angle = math.atan2(docPt.dy - center.dy, docPt.dx - center.dx);
    final startAngle = math.atan2(
      _interactionStartDoc!.dy - center.dy,
      _interactionStartDoc!.dx - center.dx,
    );
    // Screen/doc Y grows downward, so atan2 deltas already match
    // Flutter canvas.rotate (positive = clockwise). Keep additive.
    var newRotation =
        (_startRotation! + (angle - startAngle) * (180 / math.pi)) % 360;
    if (newRotation < 0) newRotation += 360;

    bloc.add(
      UpdateNodeTransformEvent(
        nodeId: node.id,
        rotation: newRotation,
        recordUndo: false,
      ),
    );
  }
}

Color _parseHex(String hex) => decodeDocumentColor(hex);

FontWeight _fontWeight(int w) {
  switch (w) {
    case 100:
      return FontWeight.w100;
    case 200:
      return FontWeight.w200;
    case 300:
      return FontWeight.w300;
    case 400:
      return FontWeight.normal;
    case 500:
      return FontWeight.w500;
    case 600:
      return FontWeight.w600;
    case 700:
      return FontWeight.bold;
    case 800:
      return FontWeight.w800;
    case 900:
      return FontWeight.w900;
    default:
      return FontWeight.normal;
  }
}

TextAlign _textAlign(String a) {
  switch (a) {
    case 'center':
      return TextAlign.center;
    case 'right':
      return TextAlign.right;
    default:
      return TextAlign.left;
  }
}
