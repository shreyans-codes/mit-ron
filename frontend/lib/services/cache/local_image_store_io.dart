import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String?> saveImageBytesToLocal(
  String fileName,
  Uint8List imageBytes,
) async {
  final directory = await getApplicationDocumentsDirectory();
  final imageDir = Directory('${directory.path}/cached_images');
  if (!await imageDir.exists()) {
    await imageDir.create(recursive: true);
  }
  final filePath = '${imageDir.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(imageBytes);
  return filePath;
}
