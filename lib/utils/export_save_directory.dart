import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Result of requesting a folder for file export (web skips the picker).
enum ExportSaveDirectoryOutcome {
  /// Call [ExportService] with [saveDirectoryPath] (null on web).
  proceed,
  /// User closed the picker without a folder.
  canceled,
  /// Picker failed (e.g. plugin error).
  failed,
}

class ExportSaveDirectoryPick {
  const ExportSaveDirectoryPick({
    required this.outcome,
    this.saveDirectoryPath,
  });

  final ExportSaveDirectoryOutcome outcome;
  final String? saveDirectoryPath;
}

/// On web, returns [proceed] with `saveDirectoryPath == null` so [ExportSaveHelper] uses FileSaver.
Future<ExportSaveDirectoryPick> pickExportSaveDirectory({
  required String dialogTitle,
}) async {
  if (kIsWeb) {
    return const ExportSaveDirectoryPick(
      outcome: ExportSaveDirectoryOutcome.proceed,
      saveDirectoryPath: null,
    );
  }
  try {
    final path = await FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle,
    );
    if (path == null || path.trim().isEmpty) {
      return const ExportSaveDirectoryPick(
        outcome: ExportSaveDirectoryOutcome.canceled,
      );
    }
    return ExportSaveDirectoryPick(
      outcome: ExportSaveDirectoryOutcome.proceed,
      saveDirectoryPath: path,
    );
  } catch (_) {
    return const ExportSaveDirectoryPick(
      outcome: ExportSaveDirectoryOutcome.failed,
    );
  }
}
