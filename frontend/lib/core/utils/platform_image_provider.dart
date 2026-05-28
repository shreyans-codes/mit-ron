import 'package:flutter/widgets.dart';
import 'platform_image_provider_web.dart'
    if (dart.library.io) 'platform_image_provider_io.dart' as impl;

ImageProvider<Object>? platformImageProvider(String? path) {
  return impl.platformImageProvider(path);
}
