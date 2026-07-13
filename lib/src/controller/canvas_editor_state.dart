import '../document/models/design_document.dart';

/// Immutable snapshot of Engine state for Host UI (toolbars, panels).
///
/// Prefer listening to [CanvasEditorController.stateStream] for live updates
/// during gestures; use [CanvasEditorController.onDocumentChanged] for
/// committed persistence.
class CanvasEditorState {
  /// Current Design Document.
  final DesignDocument document;

  /// Currently selected Node, or `null` if nothing is selected.
  final DesignNode? selectedNode;

  /// Whether [CanvasEditorController.undo] can run.
  final bool canUndo;

  /// Whether [CanvasEditorController.redo] can run.
  final bool canRedo;

  /// `true` when the undo stack is non-empty (document edited since load).
  final bool hasUnsavedChanges;

  const CanvasEditorState({
    required this.document,
    this.selectedNode,
    this.canUndo = false,
    this.canRedo = false,
    this.hasUnsavedChanges = false,
  });
}
