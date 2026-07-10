# Canvas Editor (`canvas_editor`)

A high-performance, Canva-like canvas template editor engine for Flutter. It provides an embedded editor canvas widget, a clean controller interface, reactive state streams, customizable selection borders/handles, layer ordering, undo/redo history, text reflow, background fill (color and image), callback-based image loading, dynamic custom node extension, and pixel-identical PNG export.

The library owns the **canvas engine only** — toolbars, insert bars, property panels, and colour pickers are built by the consumer app around the controller.

---

## Getting Started

### Installation

Add the dependency to your `pubspec.yaml` (path or pub reference):

```yaml
dependencies:
  canvas_editor:
    path: /path/to/canvas_editor
```

### Minimal Example

A runnable example app lives in [`example/`](example/). From the package root:

```bash
cd example
flutter run
```

Or embed the editor directly:

```dart
import 'package:flutter/material.dart';
import 'package:canvas_editor/canvas_editor.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        home: CanvasDemoScreen(),
      );
}

class CanvasDemoScreen extends StatefulWidget {
  const CanvasDemoScreen({super.key});
  @override
  State<CanvasDemoScreen> createState() => _CanvasDemoScreenState();
}

class _CanvasDemoScreenState extends State<CanvasDemoScreen> {
  late final CanvasEditorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CanvasEditorController(
      initialDocument: const DesignDocument(
        id: 'demo',
        version: 1,
        width: 1080,
        height: 1080,
        nodes: [],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Canvas Demo')),
        body: CanvasEditorWidget(controller: _controller),
      );
}
```

---

## Architecture

| Concern | Owner |
|---|---|
| Canvas rendering, gestures, selection, undo/redo | `canvas_editor` package |
| Toolbars, insert bars, property panels, routing | Consumer app |
| Document persistence / autosave | Consumer app (via `onDocumentChanged` or `stateStream`) |
| Remote / bundled image resolution | Consumer app (via `imageProvider`) |

`CanvasEditorWidget` is **zero chrome** — embed it inside your layout and drive it through `CanvasEditorController`, similar to `TextEditingController`.

---

## How to Use

### Basic Initialization & Widget Integration

```dart
import 'package:flutter/material.dart';
import 'package:canvas_editor/canvas_editor.dart';

class MyCanvasEditorScreen extends StatefulWidget {
  const MyCanvasEditorScreen({super.key});

  @override
  State<MyCanvasEditorScreen> createState() => _MyCanvasEditorScreenState();
}

class _MyCanvasEditorScreenState extends State<MyCanvasEditorScreen> {
  late final CanvasEditorController _controller;

  @override
  void initState() {
    super.initState();

    _controller = CanvasEditorController(
      initialDocument: const DesignDocument(
        id: 'new_doc_123',
        version: 1,
        width: 1080,
        height: 1080,
        nodes: [
          BackgroundNode(
            id: 'bg_1',
            frame: Rect.fromLTWH(0, 0, 1080, 1080),
            zIndex: 0,
            color: '#FFFFFFFF',
          ),
          TextNode(
            id: 'text_1',
            frame: Rect.fromLTWH(140, 200, 800, 120),
            zIndex: 1,
            text: 'Editable Canvas Template',
          ),
        ],
      ),
      // Resolve asset IDs (e.g. CDN URLs) to ImageProviders
      imageProvider: (ref) => NetworkImage(ref.assetId!),
      onDocumentChanged: (document) {
        final json = document.toJson();
        debugPrint('Autosave: $json');
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Design Editor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _controller.state.canUndo ? _controller.undo : null,
          ),
          IconButton(
            icon: const Icon(Icons.redo),
            onPressed: _controller.state.canRedo ? _controller.redo : null,
          ),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            child: CanvasEditorWidget(
              controller: _controller,
              theme: const CanvasTheme(
                handleColor: Colors.blue,
                selectionBorderColor: Colors.blueAccent,
                handleSize: 10.0,
              ),
            ),
          ),
          SizedBox(
            width: 300,
            child: StreamBuilder<CanvasEditorState>(
              stream: _controller.stateStream,
              builder: (context, snapshot) {
                final selectedNode = snapshot.data?.selectedNode;

                if (selectedNode is TextNode) {
                  return Column(
                    children: [
                      const Text('Edit Text Properties'),
                      TextField(
                        controller: TextEditingController(text: selectedNode.text),
                        onSubmitted: (value) =>
                            _controller.updateTextContent(selectedNode.id, value),
                      ),
                      ElevatedButton(
                        onPressed: () => _controller.updateTextStyle(
                          selectedNode.id,
                          fontSize: selectedNode.fontSize + 4,
                        ),
                        child: const Text('Increase Font Size'),
                      ),
                    ],
                  );
                }
                return const Center(child: Text('Select an element to edit'));
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Controller API

### Construction

```dart
_controller = CanvasEditorController({
  DesignDocument? initialDocument,
  CanvasImageProvider? imageProvider,
  List<CustomNodeType>? customNodeTypes,
  void Function(DesignDocument doc)? onDocumentChanged,
});
```

| Parameter | Purpose |
|---|---|
| `initialDocument` | Starting canvas state. Defaults to a 1080×1080 white background. |
| `imageProvider` | Resolves `assetId` references to `ImageProvider` instances (see [Image Loading](#image-loading)). |
| `customNodeTypes` | Registers consumer-defined node types at startup. |
| `onDocumentChanged` | Fires on every document mutation — useful for autosave. |

### Read API

```dart
DesignDocument get document;
CanvasEditorState get state;
Stream<CanvasEditorState> get stateStream;
```

`CanvasEditorState` exposes:

| Field | Description |
|---|---|
| `document` | Current `DesignDocument` snapshot |
| `selectedNode` | Selected `DesignNode`, or `null` |
| `canUndo` / `canRedo` | Whether history navigation is available |
| `hasUnsavedChanges` | `true` when the undo stack is non-empty |

### Selection

```dart
controller.selectNode(nodeId);   // select a node
controller.selectNode(null);     // clear selection
```

### Node Management

```dart
controller.addTextNode({String? text, Offset? position, bool select = true});
controller.addImageNode({required String localPath, bool select = true});
controller.deleteNode(String nodeId);
```

### Text Styling & Content

Text updates automatically **reflow** — frame height adjusts to fit wrapped text while width is held.

```dart
controller.updateTextStyle(
  nodeId, {
  double? fontSize,
  String? textColor,      // ARGB hex, e.g. '#FF000000'
  String? fontFamily,
  int? fontWeight,        // e.g. 400, 700
  double? lineHeight,
  double? letterSpacing,
  String? textAlign,      // 'left', 'center', 'right'
  bool recordUndo = true,
});

controller.updateTextContent(nodeId, String text, {bool recordUndo = true});
```

### Background

```dart
controller.updateBackground('#FFFFFFFF', {bool recordUndo = true});

// Set a background image (localPath and assetId are exclusive)
controller.setBackgroundImage(localPath: '/path/to/photo.jpg');
controller.setBackgroundImage(assetId: 'https://cdn.example.com/bg.png');

// Restore dormant background colour
controller.clearBackgroundImage();
```

### Layer Ordering

```dart
controller.bringForward(nodeId);
controller.sendBackward(nodeId);
controller.bringToFront(nodeId);
controller.sendToBack(nodeId);
```

### History

```dart
controller.undo();
controller.redo();
```

#### Coalesced undo for live controls (sliders, colour pickers)

Use a history session to group many mid-gesture writes into a single undo step:

```dart
_controller.beginHistorySession();

// Live updates during drag — no undo step per tick
_controller.updateTextStyle(nodeId, fontSize: 32, recordUndo: false);
_controller.updateTextStyle(nodeId, fontSize: 36, recordUndo: false);

// One undo step for the whole gesture
_controller.commitHistorySession();
```

`updateTextStyle`, `updateTextContent`, and `updateBackground` all support `recordUndo: false` for this pattern.

### Document Persistence

```dart
final json = controller.document.toJson();
// Save json to file / database

final restored = DesignDocument.fromJson(json);
controller.loadDocument(restored);
```

### Export

```dart
final Uint8List pngBytes = await controller.exportToPng(pixelRatio: 2.0);
```

Export uses the same rendering pipeline as the live canvas, so output is pixel-identical. Pass a higher `pixelRatio` for retina-quality output.

---

## Built-in Canvas Interactions

The canvas widget handles these gestures out of the box — no extra wiring required:

| Gesture | Behaviour |
|---|---|
| Tap empty area | Deselect |
| Tap node | Select |
| Tap selected text node | Start inline text editing |
| Drag node | Move |
| Corner handles (image / custom nodes) | Resize (all corners) |
| Side handles (text nodes) | Horizontal resize only (Canva-style); height reflows to fit wrapped text |
| Rotation handle | Rotate around node centre |

Text nodes use **horizontal-only resize handles** on the left and right sides. When text wraps, frame height is recalculated automatically via `TextReflow`.

---

## Image Loading

Images are referenced by `localPath` (device file) and/or `assetId` (opaque ID resolved by the consumer). The engine tries `localPath` first, then falls back to `imageProvider`.

```dart
CanvasEditorController(
  imageProvider: (CanvasImageReference ref) {
    if (ref.assetId != null) return NetworkImage(ref.assetId!);
    return const AssetImage('assets/placeholder.png');
  },
);
```

`CanvasImageReference`, `CanvasImageLoader`, and `CanvasImageProvider` are exported for advanced use (e.g. preloading images before export).

`ImageNode` supports `localPath`, `assetId`, and `fit` modes: `'cover'`, `'contain'`, `'fill'`.

---

## Document Model

`DesignDocument` is the single serializable unit. All frame values are in **document space** (not screen pixels). The library converts between document and viewport coordinates internally via `CoordinateSystem`.

### Built-in node types

| Type | Class | Key fields |
|---|---|---|
| `background` | `BackgroundNode` | `color`, `localPath`, `assetId` |
| `text` | `TextNode` | `text`, `fontFamily`, `fontSize`, `fontWeight`, `lineHeight`, `letterSpacing`, `textColor`, `textAlign` |
| `image` | `ImageNode` | `localPath`, `assetId`, `fit` |

All nodes share a common transform model:

```dart
Rect frame;       // position and size in document space
int zIndex;
double rotation;  // degrees
double scaleX;
double scaleY;
```

### Registering Custom Nodes

```dart
final customNodeTypes = [
  CustomNodeType<MyBadge>(
    type: 'my_badge',
    fromJson: (json) => MyBadge.fromJson(json),
    builder: (context, node) => MyBadgeWidget(label: node.label),
  ),
];

final controller = CanvasEditorController(customNodeTypes: customNodeTypes);
```

Custom node types participate in serialization (`DesignDocument.fromJson` dispatches by `type`), rendering, and transforms.

---

## Theming

Pass a `CanvasTheme` to `CanvasEditorWidget` to style selection chrome:

```dart
CanvasEditorWidget(
  controller: _controller,
  theme: const CanvasTheme(
    handleColor: Colors.blue,
    handleSize: 8.0,
    selectionBorderColor: Colors.blue,
    selectionBorderWidth: 1.5,
    rotationHandleColor: Colors.blue,
  ),
);
```

---

## Public Exports

The barrel file `package:canvas_editor/canvas_editor.dart` exports:

| Symbol | Purpose |
|---|---|
| `CanvasEditorController` | Primary write/read API |
| `CanvasEditorState` | Reactive state snapshot |
| `CanvasEditorWidget` | Embeddable canvas widget |
| `CanvasTheme` | Selection handle / border theming |
| `DesignDocument`, `DesignNode`, `TextNode`, `ImageNode`, `BackgroundNode` | Document model |
| `CustomNodeType`, `CustomNodeRegistry` | Node extension registry |
| `CoordinateSystem` | Document ↔ screen coordinate conversion |
| `CanvasImageReference`, `CanvasImageLoader`, `CanvasImageProvider` | Image load path |

Internal implementation (`EditorBloc`, painters, hit-testing) is private under `lib/src/` and not part of the public API.

---

## Key Features Summary

1. **Embedded editor engine** — zero chrome; consumer owns all UI around the canvas
2. **Controller + state stream** — familiar Flutter pattern; BLoC is an internal detail
3. **Document manipulation** — add/delete text and image nodes, update styles, background colour and image
4. **Text reflow** — automatic height adjustment when content or width changes
5. **Canva-style text resize** — horizontal side handles only; height follows wrapped text
6. **Inline text editing** — double-tap a selected text node to edit on canvas
7. **Drag, resize, rotate** — built-in gesture handling with rotation anchor
8. **Layer reordering** — bring forward / send backward / to front / to back
9. **Undo / redo** — with history session coalescing for live property controls
10. **Callback image loading** — `localPath` + `assetId` with consumer-provided resolver
11. **Custom node registry** — extend the canvas with your own widgets and serializers
12. **Pixel-identical PNG export** — same renderer as the live canvas
13. **JSON serialization** — `DesignDocument.toJson()` / `fromJson()` for persistence and sync
