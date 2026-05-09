/// Configuration for optional on-device strip text model (TFLite).
///
/// Replace [modelDownloadUrl] with a direct HTTPS URL to your converted
/// `.tflite` file (for example a Hugging Face `resolve/main/...` raw link).
class StripAiConfig {
  StripAiConfig._();

  static const String subdirName = 'strip_ai';
  static const String modelFileName = 'strip_text.tflite';

  /// Shown in Settings — opens in browser (model card / docs).
  static const String modelCardUrl =
      'https://huggingface.co/microsoft/trocr-base-printed';

  /// Direct download URL for the mobile `.tflite` artifact.
  /// Leave empty until you host a converted model; the app will show a message.
  static const String modelDownloadUrl = '';

  /// Displayed in Settings when a file is installed.
  static const String modelVersionLabel = '1';

  /// Optional integrity check after download (lowercase hex, no spaces).
  static const String? expectedSha256 = null;

  /// Optional expected file size in bytes (null = skip size check).
  static const int? expectedModelBytes = null;
}
