/// Canvas Editor Engine for Flutter.
///
/// Embed [CanvasEditorWidget] and drive it with [CanvasEditorController].
/// Host UI (toolbars, panels) stays in the consumer app.
///
/// ```dart
/// import 'package:flutter_canvas_editor/flutter_canvas_editor.dart';
/// ```
library;

export 'src/shared/image_load_path.dart';
export 'src/controller/canvas_editor_controller.dart';
export 'src/controller/canvas_editor_state.dart';
export 'src/widgets/canvas_editor_widget.dart';
export 'src/theme/canvas_theme.dart';
export 'src/extensions/custom_node_type.dart';
export 'src/document/models/design_document.dart';
export 'src/renderer/coordinate_system.dart';
