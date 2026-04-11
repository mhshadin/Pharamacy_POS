import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

Future<String?> writeExportToDirectory({
  required Uint8List bytes,
  required String directoryPath,
  required String baseName,
  required String fileExtension,
}) async {
  try {
    final safe = _sanitizeBaseName(baseName);
    final dir = Directory(directoryPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    var candidate = p.join(dir.path, '$safe.$fileExtension');
    if (await File(candidate).exists()) {
      var i = 1;
      do {
        candidate = p.join(dir.path, '${safe}_$i.$fileExtension');
        i++;
      } while (await File(candidate).exists());
    }
    await File(candidate).writeAsBytes(bytes, flush: true);
    return candidate;
  } catch (_) {
    return null;
  }
}

String _sanitizeBaseName(String name) {
  final s = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  if (s.isEmpty) return 'export';
  return s;
}
