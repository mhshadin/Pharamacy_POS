/// Configuration for optional on-device strip text model (ONNX or TFLite).
///
/// Default ships the OpenCV Zoo **English CRNN** ONNX from Hugging Face
/// (`text_recognition_CRNN_EN_2022oct_int8.onnx`). You may replace the URL
/// with another direct artifact link; `.onnx` and `.tflite` are detected by extension.
class StripAiConfig {
  StripAiConfig._();

  static const String subdirName = 'strip_ai';

  /// Downloaded model filename (must match [modelDownloadUrl] extension).
  static const String modelFileName = 'strip_text.onnx';

  /// Model card / docs (OpenCV CRNN on Hugging Face).
  static const String modelCardUrl =
      'https://huggingface.co/opencv/text_recognition_crnn';

  /// Direct HTTPS URL to the weight file (ONNX or TFLite).
  static const String modelDownloadUrl =
      'https://huggingface.co/opencv/text_recognition_crnn/resolve/main/text_recognition_CRNN_EN_2022oct_int8.onnx';

  /// Displayed in Settings when a file is installed.
  static const String modelVersionLabel = 'opencv-crnn-en-int8-2022oct';

  /// Optional integrity check after download (lowercase hex, no spaces).
  static const String? expectedSha256 = null;

  /// Optional expected file size in bytes (null = skip size check).
  static const int? expectedModelBytes = null;
}
