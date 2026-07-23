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

  /// `true` when the undo stack is non-empty.
  ///
  /// **Deprecated:** this is not persistence dirty state. Track Host-owned
  /// dirty flags via Committed Changes ([CanvasEditorController.onDocumentChanged]).
  /// Will be removed in 2.0.
  @Deprecated(
    'Not persistence dirty state — undo stack depth is not "unsaved". '
    'Track dirty via onDocumentChanged / Committed Changes. Removed in 2.0.',
  )
  final bool hasUnsavedChanges;

  const CanvasEditorState({
    required this.document,
    this.selectedNode,
    this.canUndo = false,
    this.canRedo = false,
    this.hasUnsavedChanges = false,
  });
}
