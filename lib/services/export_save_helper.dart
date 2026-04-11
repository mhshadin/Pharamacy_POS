import 'dart:typed_data';

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import 'export_save_io.dart' if (dart.library.html) 'export_save_stub.dart'
    as impl;

/// Writes export bytes to a user-selected folder (native) or uses [FileSaver].
class ExportSaveHelper {
  ExportSaveHelper._();

  /// [baseName] should not include the extension (e.g. `This_Week_sales_report`).
  static Future<String?> save({
    required Uint8List bytes,
    required String baseName,
    required String fileExtension,
    required MimeType mimeType,
    String? saveDirectoryPath,
  }) async {
    final dir = saveDirectoryPath?.trim();
    if (!kIsWeb && dir != null && dir.isNotEmpty) {
      final path = await impl.writeExportToDirectory(
        bytes: bytes,
        directoryPath: dir,
        baseName: baseName,
        fileExtension: fileExtension,
      );
      if (path != null) return path;
      debugPrint(
        'ExportSaveHelper: directory write failed or unavailable, using FileSaver',
      );
    }
    try {
      return await FileSaver.instance.saveFile(
        name: baseName,
        bytes: bytes,
        fileExtension: fileExtension,
        mimeType: mimeType,
      );
    } catch (e) {
      debugPrint('ExportSaveHelper FileSaver: $e');
      return null;
    }
  }
}
