import 'package:flutter/widgets.dart';

ImageProvider<Object>? platformImageProvider(String? path) {
  if (path == null || path.isEmpty) return null;
  return NetworkImage(path);
}
