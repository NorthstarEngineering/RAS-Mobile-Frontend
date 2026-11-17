import 'dart:io';
import 'dart:typed_data';

Future<String> saveFileBytes(Uint8List bytes, String filename, String mimeType) async {
  final candidates = [
    '/sdcard/Download',
    '/sdcard/Documents',
    Platform.environment['HOME'] != null ? '${Platform.environment['HOME']}/Downloads' : null,
    Directory.systemTemp.path,
  ];

  Directory? targetDir;
  for (final path in candidates) {
    if (path != null) {
      final dir = Directory(path);
      if (dir.existsSync()) {
        targetDir = dir;
        break;
      }
    }
  }
  targetDir ??= Directory.systemTemp;
  final file = File('${targetDir.path}/$filename');
  await file.writeAsBytes(bytes);
  return file.path;
}
