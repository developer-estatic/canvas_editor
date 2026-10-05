import 'dart:io';

import 'package:flutter/painting.dart';

ImageProvider<Object>? createFileImage(String path) => FileImage(File(path));
