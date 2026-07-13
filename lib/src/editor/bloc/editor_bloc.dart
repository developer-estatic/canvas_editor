import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../document/models/design_document.dart';

// --- EVENTS ---
abstract class EditorEvent {}

class LoadDocumentEvent extends EditorEvent {
  final DesignDocument document;
  LoadDocumentEvent(this.document);
}

class UpdateNodeFrameEvent extends EditorEvent {
  final String nodeId;
  final Rect newFrame;
  final bool recordUndo;
  UpdateNodeFrameEvent(this.nodeId, this.newFrame, {this.recordUndo = true});
}

class UpdateNodeTextEvent extends EditorEvent {
  final String nodeId;
  final String newText;
  final bool recordUndo;
  UpdateNodeTextEvent(this.nodeId, this.newText, {this.recordUndo = true});
}

class UpdateBackgroundColorEvent extends EditorEvent {
  final String colorHex;
  final bool recordUndo;
  UpdateBackgroundColorEvent(this.colorHex, {this.recordUndo = true});
}

class SetBackgroundImageEvent extends EditorEvent {
  final String? localPath;
  final String? assetId;
  SetBackgroundImageEvent({this.localPath, this.assetId});
}

class ClearBackgroundImageEvent extends EditorEvent {}

class SelectNodeEvent extends EditorEvent {
  final String? nodeId;
  SelectNodeEvent(this.nodeId);
}

class UpdateNodeEvent extends EditorEvent {
  final DesignNode node;
  final bool recordUndo;
  UpdateNodeEvent(this.node, {this.recordUndo = true});
}

class UpdateViewportEvent extends EditorEvent {
  final double scale;
  final Offset offset;
  UpdateViewportEvent(this.scale, this.offset);
}

class UpdateNodeTransformEvent extends EditorEvent {
  final String nodeId;
  final double? rotation;
  final double? scaleX;
  final double? scaleY;
  final bool recordUndo;
  UpdateNodeTransformEvent({
    required this.nodeId,
    this.rotation,
    this.scaleX,
    this.scaleY,
    this.recordUndo = true,
  });
}

/// Pushes [snapshot] onto the undo stack once (e.g. end of drag/resize/rotate).
class CommitHistoryEvent extends EditorEvent {
  final DesignDocument snapshot;
  CommitHistoryEvent(this.snapshot);
}

class AddImageNodeEvent extends EditorEvent {
  final String localPath;
  final String fit;
  final bool select;
  AddImageNodeEvent(
    this.localPath, {
    this.fit = 'cover',
    this.select = true,
  });
}

class AddTextNodeEvent extends EditorEvent {
  final String text;
  final Offset position;
  final bool select;
  AddTextNodeEvent(
    this.text,
    this.position, {
    this.select = true,
  });
}

class DeleteNodeEvent extends EditorEvent {
  final String nodeId;
  DeleteNodeEvent(this.nodeId);
}

enum LayerReorderAction {
  bringForward,
  sendBackward,
  bringToFront,
  sendToBack,
}

class LayerReorderEvent extends EditorEvent {
  final String nodeId;
  final LayerReorderAction action;
  LayerReorderEvent(this.nodeId, this.action);
}

class UndoEvent extends EditorEvent {}

class RedoEvent extends EditorEvent {}

// --- STATE ---
class EditorState {
  final DesignDocument document;
  final String? selectedNodeId;
  final double viewportScale;
  final Offset viewportOffset;
  final List<DesignDocument> undoStack;
  final List<DesignDocument> redoStack;

  /// One-shot pulse: this emission is a committed Design Document change
  /// (same moments as undo recording / history commit). Mid-gesture updates
  /// leave this false so Host UI can use [CanvasEditorController.onDocumentChanged]
  /// like Slider.onChangeEnd while [stateStream] stays live.
  final bool documentCommitted;

  const EditorState({
    required this.document,
    this.selectedNodeId,
    this.viewportScale = 1.0,
    this.viewportOffset = Offset.zero,
    this.undoStack = const [],
    this.redoStack = const [],
    this.documentCommitted = false,
  });

  EditorState copyWith({
    DesignDocument? document,
    String? selectedNodeId,
    bool clearSelection = false,
    double? viewportScale,
    Offset? viewportOffset,
    List<DesignDocument>? undoStack,
    List<DesignDocument>? redoStack,
    bool documentCommitted = false,
  }) {
    return EditorState(
      document: document ?? this.document,
      selectedNodeId: clearSelection ? null : (selectedNodeId ?? this.selectedNodeId),
      viewportScale: viewportScale ?? this.viewportScale,
      viewportOffset: viewportOffset ?? this.viewportOffset,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      documentCommitted: documentCommitted,
    );
  }
}

// --- BLOC ---
class EditorBloc extends Bloc<EditorEvent, EditorState> {
  EditorBloc(DesignDocument initialDoc)
      : super(EditorState(document: initialDoc)) {
    on<LoadDocumentEvent>(_onLoadDocument);
    on<UpdateNodeFrameEvent>(_onUpdateNodeFrame);
    on<UpdateNodeTextEvent>(_onUpdateNodeText);
    on<UpdateBackgroundColorEvent>(_onUpdateBackgroundColor);
    on<SetBackgroundImageEvent>(_onSetBackgroundImage);
    on<ClearBackgroundImageEvent>(_onClearBackgroundImage);
    on<SelectNodeEvent>(_onSelectNode);
    on<UpdateViewportEvent>(_onUpdateViewport);
    on<UpdateNodeEvent>(_onUpdateNode);
    on<UpdateNodeTransformEvent>(_onUpdateNodeTransform);
    on<AddImageNodeEvent>(_onAddImageNode);
    on<AddTextNodeEvent>(_onAddTextNode);
    on<DeleteNodeEvent>(_onDeleteNode);
    on<LayerReorderEvent>(_onLayerReorder);
    on<UndoEvent>(_onUndo);
    on<RedoEvent>(_onRedo);
    on<CommitHistoryEvent>(_onCommitHistory);
  }

  void _onUpdateNode(UpdateNodeEvent event, Emitter<EditorState> emit) {
    final updatedNodes = state.document.nodes.map((node) {
      if (node.id == event.node.id) {
        return event.node;
      }
      return node;
    }).toList();

    _updateDocumentAndPushUndo(
      emit,
      state.document.copyWith(nodes: updatedNodes),
      recordUndo: event.recordUndo,
    );
  }

  void _onLoadDocument(LoadDocumentEvent event, Emitter<EditorState> emit) {
    emit(EditorState(document: event.document, documentCommitted: true));
  }

  void _onUpdateNodeFrame(UpdateNodeFrameEvent event, Emitter<EditorState> emit) {
    final updatedNodes = state.document.nodes.map((node) {
      if (node.id == event.nodeId) {
        return node.copyWith(frame: event.newFrame);
      }
      return node;
    }).toList();

    _updateDocumentAndPushUndo(
      emit,
      state.document.copyWith(nodes: updatedNodes),
      recordUndo: event.recordUndo,
    );
  }

  void _onUpdateNodeText(UpdateNodeTextEvent event, Emitter<EditorState> emit) {
    final updatedNodes = state.document.nodes.map((node) {
      if (node.id == event.nodeId && node is TextNode) {
        return node.copyWith(text: event.newText);
      }
      return node;
    }).toList();

    _updateDocumentAndPushUndo(
      emit,
      state.document.copyWith(nodes: updatedNodes),
      recordUndo: event.recordUndo,
    );
  }

  void _onUpdateBackgroundColor(UpdateBackgroundColorEvent event, Emitter<EditorState> emit) {
    final updatedNodes = state.document.nodes.map((node) {
      if (node is BackgroundNode) {
        return node.copyWith(
          color: event.colorHex,
          localPath: null,
          assetId: null,
        );
      }
      return node;
    }).toList();

    // If no background node exists, add one at zIndex 0
    if (!state.document.nodes.any((node) => node is BackgroundNode)) {
      updatedNodes.insert(
        0,
        BackgroundNode(
          id: 'bg_node',
          frame: Rect.fromLTWH(0, 0, state.document.width, state.document.height),
          zIndex: 0,
          color: event.colorHex,
        ),
      );
    }

    _updateDocumentAndPushUndo(
      emit,
      state.document.copyWith(nodes: updatedNodes),
      recordUndo: event.recordUndo,
    );
  }

  void _onSetBackgroundImage(SetBackgroundImageEvent event, Emitter<EditorState> emit) {
    final hasLocal = event.localPath != null && event.localPath!.isNotEmpty;
    final hasAsset = event.assetId != null && event.assetId!.isNotEmpty;
    if (!hasLocal && !hasAsset) return;

    final updatedNodes = state.document.nodes.map((node) {
      if (node is BackgroundNode) {
        return node.copyWith(
          localPath: hasLocal ? event.localPath : null,
          assetId: hasAsset ? event.assetId : null,
        );
      }
      return node;
    }).toList();

    if (!state.document.nodes.any((node) => node is BackgroundNode)) {
      updatedNodes.insert(
        0,
        BackgroundNode(
          id: 'bg_node',
          frame: Rect.fromLTWH(0, 0, state.document.width, state.document.height),
          zIndex: 0,
          color: '#FFFFFFFF',
          localPath: hasLocal ? event.localPath : null,
          assetId: hasAsset ? event.assetId : null,
        ),
      );
    }

    _updateDocumentAndPushUndo(
      emit,
      state.document.copyWith(nodes: updatedNodes),
      clearSelection: true,
    );
  }

  void _onClearBackgroundImage(ClearBackgroundImageEvent event, Emitter<EditorState> emit) {
    final updatedNodes = state.document.nodes.map((node) {
      if (node is BackgroundNode) {
        return node.copyWith(localPath: null, assetId: null);
      }
      return node;
    }).toList();

    _updateDocumentAndPushUndo(
      emit,
      state.document.copyWith(nodes: updatedNodes),
      clearSelection: true,
    );
  }

  void _onSelectNode(SelectNodeEvent event, Emitter<EditorState> emit) {
    if (event.nodeId == null) {
      emit(state.copyWith(clearSelection: true));
    } else {
      emit(state.copyWith(selectedNodeId: event.nodeId));
    }
  }

  void _onUpdateViewport(UpdateViewportEvent event, Emitter<EditorState> emit) {
    emit(state.copyWith(
      viewportScale: event.scale,
      viewportOffset: event.offset,
    ));
  }

  void _onUndo(UndoEvent event, Emitter<EditorState> emit) {
    if (state.undoStack.isEmpty) return;

    final previousDoc = state.undoStack.last;
    final remainingUndo = List<DesignDocument>.from(state.undoStack)..removeLast();
    final newRedo = List<DesignDocument>.from(state.redoStack)..add(state.document);

    emit(state.copyWith(
      document: previousDoc,
      undoStack: remainingUndo,
      redoStack: newRedo,
      documentCommitted: true,
    ));
  }

  void _onRedo(RedoEvent event, Emitter<EditorState> emit) {
    if (state.redoStack.isEmpty) return;

    final nextDoc = state.redoStack.last;
    final remainingRedo = List<DesignDocument>.from(state.redoStack)..removeLast();
    final newUndo = List<DesignDocument>.from(state.undoStack)..add(state.document);

    emit(state.copyWith(
      document: nextDoc,
      undoStack: newUndo,
      redoStack: remainingRedo,
      documentCommitted: true,
    ));
  }

  void _onUpdateNodeTransform(UpdateNodeTransformEvent event, Emitter<EditorState> emit) {
    final updatedNodes = state.document.nodes.map((node) {
      if (node.id == event.nodeId) {
        return node.copyWith(
          rotation: event.rotation,
          scaleX: event.scaleX,
          scaleY: event.scaleY,
        );
      }
      return node;
    }).toList();

    _updateDocumentAndPushUndo(
      emit,
      state.document.copyWith(nodes: updatedNodes),
      recordUndo: event.recordUndo,
    );
  }

  void _onCommitHistory(CommitHistoryEvent event, Emitter<EditorState> emit) {
    if (event.snapshot == state.document) return;

    final newUndoStack = List<DesignDocument>.from(state.undoStack)
      ..add(event.snapshot);
    emit(state.copyWith(
      undoStack: newUndoStack,
      redoStack: const [],
      documentCommitted: true,
    ));
  }

  Future<Size> _getImageSize(String path) async {
    final bytes = await io.File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    final image = frameInfo.image;
    final size = Size(image.width.toDouble(), image.height.toDouble());
    image.dispose();
    codec.dispose();
    return size;
  }

  Future<void> _onAddImageNode(AddImageNodeEvent event, Emitter<EditorState> emit) async {
    final doc = state.document;
    final maxZ = doc.nodes.fold<int>(0, (max, n) => n.zIndex > max ? n.zIndex : max);

    final imageSize = await _getImageSize(event.localPath);
    const maxDimension = 300.0;
    final w = imageSize.width >= imageSize.height
        ? maxDimension
        : maxDimension * (imageSize.width / imageSize.height);
    final h = imageSize.width >= imageSize.height
        ? maxDimension * (imageSize.height / imageSize.width)
        : maxDimension;

    final x = (doc.width - w) / 2;
    final y = (doc.height - h) / 2;

    final newNode = ImageNode(
      id: 'img_${DateTime.now().millisecondsSinceEpoch}',
      frame: Rect.fromLTWH(x, y, w, h),
      zIndex: maxZ + 1,
      localPath: event.localPath,
      fit: event.fit,
    );

    final updatedNodes = List<DesignNode>.from(doc.nodes)..add(newNode);
    _updateDocumentAndPushUndo(
      emit,
      doc.copyWith(nodes: updatedNodes),
      selectNodeId: event.select ? newNode.id : null,
    );
  }

  void _onAddTextNode(AddTextNodeEvent event, Emitter<EditorState> emit) {
    final doc = state.document;
    final maxZ = doc.nodes.fold<int>(0, (max, n) => n.zIndex > max ? n.zIndex : max);
    final id = 'text_${DateTime.now().millisecondsSinceEpoch}';
    final newNode = TextNode(
      id: id,
      frame: Rect.fromLTWH(event.position.dx, event.position.dy, 300, 100),
      zIndex: maxZ + 1,
      text: event.text.isEmpty ? 'Double tap to edit' : event.text,
    );
    final updatedNodes = List<DesignNode>.from(doc.nodes)..add(newNode);
    _updateDocumentAndPushUndo(
      emit,
      doc.copyWith(nodes: updatedNodes),
      selectNodeId: event.select ? id : null,
    );
  }

  void _onDeleteNode(DeleteNodeEvent event, Emitter<EditorState> emit) {
    final doc = state.document;
    final updatedNodes = doc.nodes.where((n) => n.id != event.nodeId).toList();
    
    final clearSelection = state.selectedNodeId == event.nodeId;
    if (clearSelection) {
      emit(state.copyWith(clearSelection: true));
    }
    _updateDocumentAndPushUndo(emit, doc.copyWith(nodes: updatedNodes));
  }

  void _onLayerReorder(LayerReorderEvent event, Emitter<EditorState> emit) {
    final doc = state.document;
    final bgNode = doc.nodes.cast<DesignNode?>().firstWhere((n) => n is BackgroundNode, orElse: () => null);
    final otherNodes = doc.nodes.where((n) => n is! BackgroundNode).toList()
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));
    
    final targetIndex = otherNodes.indexWhere((n) => n.id == event.nodeId);
    if (targetIndex == -1) return;

    switch (event.action) {
      case LayerReorderAction.bringForward:
        if (targetIndex < otherNodes.length - 1) {
          final temp = otherNodes[targetIndex];
          otherNodes[targetIndex] = otherNodes[targetIndex + 1];
          otherNodes[targetIndex + 1] = temp;
        }
        break;
      case LayerReorderAction.sendBackward:
        if (targetIndex > 0) {
          final temp = otherNodes[targetIndex];
          otherNodes[targetIndex] = otherNodes[targetIndex - 1];
          otherNodes[targetIndex - 1] = temp;
        }
        break;
      case LayerReorderAction.bringToFront:
        final node = otherNodes.removeAt(targetIndex);
        otherNodes.add(node);
        break;
      case LayerReorderAction.sendToBack:
        final node = otherNodes.removeAt(targetIndex);
        otherNodes.insert(0, node);
        break;
    }

    final updatedNodes = <DesignNode>[];
    if (bgNode != null) {
      updatedNodes.add(bgNode.copyWith(zIndex: 0));
    }
    for (int i = 0; i < otherNodes.length; i++) {
      updatedNodes.add(otherNodes[i].copyWith(zIndex: i + 1));
    }

    _updateDocumentAndPushUndo(emit, doc.copyWith(nodes: updatedNodes));
  }

  void _updateDocumentAndPushUndo(
    Emitter<EditorState> emit,
    DesignDocument newDoc, {
    bool recordUndo = true,
    String? selectNodeId,
    bool clearSelection = false,
  }) {
    if (newDoc == state.document) return;

    if (!recordUndo) {
      emit(state.copyWith(
        document: newDoc,
        selectedNodeId: selectNodeId,
        clearSelection: clearSelection,
        documentCommitted: false,
      ));
      return;
    }

    final newUndoStack = List<DesignDocument>.from(state.undoStack)..add(state.document);
    emit(state.copyWith(
      document: newDoc,
      undoStack: newUndoStack,
      redoStack: const [], // Clear redo history on new action
      selectedNodeId: selectNodeId,
      clearSelection: clearSelection,
      documentCommitted: true,
    ));
  }
}
