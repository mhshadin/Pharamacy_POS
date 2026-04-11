import 'dart:typed_data';

/// Web stub — directory writes are not used (`kIsWeb` branch in [ExportSaveHelper]).
Future<String?> writeExportToDirectory({
  required Uint8List bytes,
  required String directoryPath,
  required String baseName,
  required String fileExtension,
}) async =>
    null;
