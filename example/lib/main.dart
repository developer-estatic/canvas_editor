import 'package:flutter_canvas_editor/flutter_canvas_editor.dart';
import 'package:flutter/material.dart';

import 'io_file_image.dart';

void main() => runApp(const CanvasEditorExampleApp());

/// Minimal runnable demo for [flutter_canvas_editor].
///
/// Shows controller setup, [CanvasEditorWidget] embedding, undo/redo,
/// adding text, and a small property panel driven by [stateStream].
class CanvasEditorExampleApp extends StatelessWidget {
  const CanvasEditorExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Canvas Editor Example',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const CanvasDemoScreen(),
    );
  }
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
      imageProvider: _exampleImageProvider,
      initialDocument: const DesignDocument(
        id: 'example_doc',
        version: 1,
        width: 1080,
        height: 1080,
        nodes: [
          BackgroundNode(
            id: 'bg_1',
            frame: Rect.fromLTWH(0, 0, 1080, 1080),
            zIndex: 0,
            color: '#FFF5F0E8',
          ),
          TextNode(
            id: 'text_1',
            frame: Rect.fromLTWH(140, 420, 800, 120),
            zIndex: 1,
            text: 'Tap to select · Tap again to edit',
            fontSize: 36,
            textAlign: 'center',
          ),
        ],
      ),
      onDocumentChanged: (document) {
        debugPrint('Document committed (${document.nodes.length} nodes)');
      },
    );
  }

  /// Demonstrates file / network / internal-asset branching in one callback.
  ///
  /// Host convention for opaque [CanvasImageReference.assetId] values:
  /// - `http(s)://…` → network
  /// - `asset:path/in/bundle.png` → bundled [AssetImage]
  /// - anything else → treat as network URL (or your catalog lookup)
  ///
  /// `localPath` is preferred by the Engine load order before this callback runs;
  /// the file branch here covers export/precache paths that still invoke the provider.
  ImageProvider _exampleImageProvider(CanvasImageReference ref) {
    if (ref.localPath != null && ref.localPath!.isNotEmpty) {
      final fileImage = createFileImage(ref.localPath!);
      if (fileImage != null) return fileImage;
    }
    final id = ref.assetId;
    if (id == null || id.isEmpty) {
      throw ArgumentError(
        'CanvasImageReference has no resolvable image source',
      );
    }
    if (id.startsWith('http://') || id.startsWith('https://')) {
      return NetworkImage(id);
    }
    if (id.startsWith('asset:')) {
      return AssetImage(id.substring('asset:'.length));
    }
    return NetworkImage(id);
  }

  Future<void> _exportPng() async {
    final bytes = await _controller.exportToPng();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${bytes.length} bytes PNG')),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  static const _wideLayoutBreakpoint = 720.0;

  @override
  Widget build(BuildContext context) {
    final canvas = CanvasEditorWidget(
      controller: _controller,
      theme: const CanvasTheme(
        handleColor: Colors.indigo,
        selectionBorderColor: Colors.indigoAccent,
        handleSize: 10,
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Canvas Editor Example'),
        actions: [
          StreamBuilder<CanvasEditorState>(
            stream: _controller.stateStream,
            initialData: _controller.state,
            builder: (context, snapshot) {
              final canUndo = snapshot.data?.canUndo ?? false;
              final canRedo = snapshot.data?.canRedo ?? false;
              return Row(
                children: [
                  IconButton(
                    tooltip: 'Undo',
                    onPressed: canUndo ? _controller.undo : null,
                    icon: const Icon(Icons.undo),
                  ),
                  IconButton(
                    tooltip: 'Redo',
                    onPressed: canRedo ? _controller.redo : null,
                    icon: const Icon(Icons.redo),
                  ),
                  IconButton(
                    tooltip: 'Export PNG',
                    onPressed: _exportPng,
                    icon: const Icon(Icons.download),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final useSidePanel = constraints.maxWidth >= _wideLayoutBreakpoint;

          if (useSidePanel) {
            return Row(
              children: [
                Expanded(child: canvas),
                SizedBox(
                  width: 280,
                  child: _PropertyPanel(controller: _controller),
                ),
              ],
            );
          }

          return canvas;
        },
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= _wideLayoutBreakpoint) {
            return const SizedBox.shrink();
          }
          return _MobileChrome(controller: _controller);
        },
      ),
    );
  }
}

class _MobileChrome extends StatelessWidget {
  const _MobileChrome({required this.controller});

  final CanvasEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: StreamBuilder<CanvasEditorState>(
          stream: controller.stateStream,
          initialData: controller.state,
          builder: (context, snapshot) {
            final selected = snapshot.data?.selectedNode;

            if (selected is TextNode) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Text properties',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Content',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      controller: TextEditingController(text: selected.text),
                      onSubmitted: (value) =>
                          controller.updateTextContent(selected.id, value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => controller.updateTextStyle(
                              selected.id,
                              fontSize: selected.fontSize - 2,
                            ),
                            child: const Text('A−'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => controller.updateTextStyle(
                              selected.id,
                              fontSize: selected.fontSize + 2,
                            ),
                            child: const Text('A+'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Delete',
                          onPressed: () => controller.deleteNode(selected.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: () => controller.addTextNode(text: 'New text'),
                icon: const Icon(Icons.text_fields),
                label: const Text('Add text'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PropertyPanel extends StatelessWidget {
  const _PropertyPanel({required this.controller});

  final CanvasEditorController controller;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      child: StreamBuilder<CanvasEditorState>(
        stream: controller.stateStream,
        initialData: controller.state,
        builder: (context, snapshot) {
          final state = snapshot.data;
          final selected = state?.selectedNode;

          if (selected is TextNode) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Text properties',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    border: OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: selected.text),
                  onSubmitted: (value) =>
                      controller.updateTextContent(selected.id, value),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.updateTextStyle(
                          selected.id,
                          fontSize: selected.fontSize - 2,
                        ),
                        child: const Text('A−'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => controller.updateTextStyle(
                          selected.id,
                          fontSize: selected.fontSize + 2,
                        ),
                        child: const Text('A+'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () => controller.deleteNode(selected.id),
                  child: const Text('Delete'),
                ),
              ],
            );
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Select an element on the canvas to edit it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => controller.addTextNode(text: 'New text'),
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Add text'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
