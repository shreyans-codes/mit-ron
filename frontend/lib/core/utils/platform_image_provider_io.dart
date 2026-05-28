import 'dart:io';
import 'package:flutter/widgets.dart';

ImageProvider<Object>? platformImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  return FileImage(File(path));
}
