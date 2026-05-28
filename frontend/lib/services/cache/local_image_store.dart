import 'dart:typed_data';
import 'local_image_store_web.dart'
    if (dart.library.io) 'local_image_store_io.dart' as impl;

Future<String?> saveImageBytesToLocal(
  String fileName,
  Uint8List imageBytes,
) async {
  return impl.saveImageBytesToLocal(fileName, imageBytes);
}
