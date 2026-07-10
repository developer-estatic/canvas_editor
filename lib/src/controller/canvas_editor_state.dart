import '../document/models/design_document.dart';

class CanvasEditorState {
  final DesignDocument document;
  final DesignNode? selectedNode; // null = nothing selected
  final bool canUndo;
  final bool canRedo;
  final bool hasUnsavedChanges;

  const CanvasEditorState({
    required this.document,
    this.selectedNode,
    this.canUndo = false,
    this.canRedo = false,
    this.hasUnsavedChanges = false,
  });
}
