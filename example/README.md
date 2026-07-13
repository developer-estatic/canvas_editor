# Canvas Editor Example

Runnable Host UI demo for [`flutter_canvas_editor`](../).

## Run

From the package root:

```bash
cd example
flutter pub get
flutter run
```

## What it shows

| Topic | Where |
|---|---|
| Controller + initial `DesignDocument` | `lib/main.dart` |
| Zero-chrome `CanvasEditorWidget` + Host toolbar / property panel | `lib/main.dart` |
| Live UI via `stateStream` | undo buttons, property panel |
| Committed changes via `onDocumentChanged` | `debugPrint` in `initState` |
| PNG export | App bar export action |
| `imageProvider` for assets / files | `_exampleImageProvider` |

Full API: [package README](../README.md).
