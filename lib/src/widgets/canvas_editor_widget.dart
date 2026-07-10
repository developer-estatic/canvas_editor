import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../controller/canvas_editor_controller.dart';
import '../theme/canvas_theme.dart';
import '../canvas_editor/canvas_editor.dart';

class CanvasEditorWidget extends StatelessWidget {
  final CanvasEditorController controller;
  final CanvasTheme? theme;

  const CanvasEditorWidget({
    super.key,
    required this.controller,
    this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: controller.bloc,
      child: CanvasEditor(
        theme: theme ?? const CanvasTheme(),
        imageProvider: controller.imageProvider,
      ),
    );
  }
}
