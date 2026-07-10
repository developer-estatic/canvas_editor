# Canvas Editor Example

Runnable demo for the [`canvas_editor`](../) package.

## Run

```bash
cd packages/canvas_editor/example
flutter pub get
flutter run
```

## What it demonstrates

- Creating a [`CanvasEditorController`](../lib/src/controller/canvas_editor_controller.dart) with an initial [`DesignDocument`](../lib/src/document/models/design_document.dart)
- Embedding [`CanvasEditorWidget`](../lib/src/widgets/canvas_editor_widget.dart) (zero chrome — the example adds its own toolbar and property panel)
- Undo / redo and PNG export via the controller API
- Reactive UI with [`stateStream`](../lib/src/controller/canvas_editor_state.dart)
- A minimal [`imageProvider`](../lib/src/shared/image_load_path.dart) for asset IDs and local files

See the [package README](../README.md) for the full API reference.
