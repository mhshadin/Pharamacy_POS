import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'strip_ai_config.dart';

class StripAiDownloadException implements Exception {
  StripAiDownloadException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Persists optional TFLite strip reader under application support storage.
class StripAiModelStore {
  StripAiModelStore._();
  static final StripAiModelStore instance = StripAiModelStore._();

  Future<Directory> _stripDir() async {
    final root = await getApplicationSupportDirectory();
    final dir = Directory(p.join(root.path, StripAiConfig.subdirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> modelFile() async {
    final dir = await _stripDir();
    return File(p.join(dir.path, StripAiConfig.modelFileName));
  }

  Future<bool> isInstalled() async {
    final f = await modelFile();
    if (!await f.exists()) return false;
    try {
      return await f.length() > 0;
    } catch (_) {
      return false;
    }
  }

  /// Streams download to disk; [onProgress] receives 0.0–1.0 when Content-Length known.
  Future<void> download({
    void Function(double progress)? onProgress,
    String? urlOverride,
  }) async {
    final url = (urlOverride ?? StripAiConfig.modelDownloadUrl).trim();
    if (url.isEmpty) {
      throw StripAiDownloadException('stripAiDownloadUrlNotConfigured');
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      throw StripAiDownloadException('stripAiInvalidUrl');
    }

    final out = await modelFile();
    final tmp = File('${out.path}.download');

    final client = http.Client();
    var finishedOk = false;
    try {
      final request = http.Request('GET', uri);
      final response = await client.send(request);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StripAiDownloadException(
          'stripAiDownloadHttp ${response.statusCode}',
        );
      }

      final expectedLen = StripAiConfig.expectedModelBytes;
      final total = response.contentLength;
      var received = 0;

      final sink = tmp.openWrite();
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          if (total != null && total > 0) {
            onProgress?.call((received / total).clamp(0.0, 1.0));
          } else {
            onProgress?.call(-1);
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (expectedLen != null && received != expectedLen) {
        await _safeDelete(tmp);
        throw StripAiDownloadException('stripAiDownloadSizeMismatch');
      }

      final hash = StripAiConfig.expectedSha256;
      if (hash != null && hash.isNotEmpty) {
        final digest = await sha256.bind(tmp.openRead()).first;
        if (digest.toString().toLowerCase() != hash.toLowerCase()) {
          await _safeDelete(tmp);
          throw StripAiDownloadException('stripAiDownloadHashMismatch');
        }
      }

      if (await out.exists()) {
        await out.delete();
      }
      await tmp.rename(out.path);
      finishedOk = true;
      onProgress?.call(1.0);
    } finally {
      if (!finishedOk) await _safeDelete(tmp);
      client.close();
    }
  }

  Future<void> deleteModel() async {
    final f = await modelFile();
    await _safeDelete(f);
  }

  Future<void> _safeDelete(File f) async {
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
