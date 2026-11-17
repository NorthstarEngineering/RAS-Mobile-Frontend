import 'dart:typed_data';

import 'file_saver_stub.dart'
    if (dart.library.js_interop) 'file_saver_web.dart'
    as platform;

/// Cross-platform utility that saves bytes to device or triggers browser download.
/// Returns the saved file path or downloaded filename.
Future<String> saveFile(Uint8List bytes, String filename, String mimeType) =>
    platform.saveFileBytes(bytes, filename, mimeType);
