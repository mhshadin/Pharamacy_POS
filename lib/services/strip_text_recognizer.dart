import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import 'strip_ai_model_store.dart';

/// On-device TFLite text recognition for strip crops (CRNN-style: [B,H,W,C] → [B,T,C]).
class StripTextRecognizer {
  StripTextRecognizer._();
  static final StripTextRecognizer instance = StripTextRecognizer._();

  static const _charsetAsset = 'assets/strip_ai/ocr_charset.txt';

  Interpreter? _interpreter;
  List<String> _charset = [];
  String? _loadedPath;
  int _loadedMtimeMs = 0;

  List<String> get charset => _charset;

  void unload() {
    try {
      _interpreter?.close();
    } catch (_) {}
    _interpreter = null;
    _loadedPath = null;
    _loadedMtimeMs = 0;
  }

  Future<List<String>> _loadCharset() async {
    final raw = await rootBundle.loadString(_charsetAsset);
    final symbols = <String>[];
    for (final line in raw.split('\n')) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      symbols.add(t);
    }
    return symbols;
  }

  /// Loads model from [StripAiModelStore] if present and valid.
  Future<bool> ensureLoaded() async {
    final file = await StripAiModelStore.instance.modelFile();
    if (!await file.exists()) {
      unload();
      return false;
    }

    int mtimeMs;
    try {
      mtimeMs = (await file.stat()).modified.millisecondsSinceEpoch;
    } catch (_) {
      unload();
      return false;
    }

    if (_interpreter != null &&
        _loadedPath == file.path &&
        _loadedMtimeMs == mtimeMs) {
      return true;
    }

    unload();
    try {
      _charset = await _loadCharset();
      if (_charset.isEmpty) return false;

      final interpreter = Interpreter.fromFile(file);
      final inT = interpreter.getInputTensors().first;
      final outT = interpreter.getOutputTensors().first;
      final ishape = inT.shape;
      final oshape = outT.shape;

      if (ishape.length != 4) {
        interpreter.close();
        return false;
      }
      final int numClasses;
      if (oshape.length == 3) {
        numClasses = oshape[2];
      } else if (oshape.length == 2) {
        numClasses = oshape[1];
      } else {
        interpreter.close();
        return false;
      }
      if (numClasses != _charset.length + 1) {
        debugPrint(
          'StripTextRecognizer: output classes $numClasses != charset+1 ${_charset.length + 1}',
        );
        interpreter.close();
        return false;
      }

      _interpreter = interpreter;
      _loadedPath = file.path;
      _loadedMtimeMs = mtimeMs;
      return true;
    } catch (e, st) {
      debugPrint('StripTextRecognizer load failed: $e\n$st');
      unload();
      return false;
    }
  }

  /// Runs recognition on each [boxes] crop; returns `null` entries when inference fails.
  Future<List<String?>> readStripsFromFile(
    File imageFile,
    List<Rect> boxes,
  ) async {
    if (!await ensureLoaded() || _interpreter == null || boxes.isEmpty) {
      return List<String?>.filled(boxes.length, null);
    }

    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return List<String?>.filled(boxes.length, null);

    final results = <String?>[];
    for (final box in boxes) {
      try {
        results.add(_runOnCrop(decoded, box));
      } catch (_) {
        results.add(null);
      }
    }
    return results;
  }

  String? _runOnCrop(img.Image full, Rect box) {
    final interpreter = _interpreter!;
    final inTensor = interpreter.getInputTensors().first;
    final outTensor = interpreter.getOutputTensors().first;
    final ishape = inTensor.shape;

    final tw = ishape[2];
    final th = ishape[1];
    final ch = ishape[3];
    if (tw <= 0 || th <= 0 || (ch != 1 && ch != 3)) return null;

    final left = (box.left - 8).floor().clamp(0, full.width - 1);
    final top = (box.top - 4).floor().clamp(0, full.height - 1);
    final right = (box.right + 8).ceil().clamp(1, full.width);
    final bottom = (box.bottom + 4).ceil().clamp(1, full.height);
    final cw = (right - left).clamp(1, full.width);
    final chh = (bottom - top).clamp(1, full.height);

    var crop = img.copyCrop(full, x: left, y: top, width: cw, height: chh);
    crop = img.copyResize(crop, width: tw, height: th);

    final inputType = inTensor.type;
    Object input;
    if (inputType == TensorType.float32) {
      input = _buildFloatInput(crop, th, tw, ch);
    } else if (inputType == TensorType.uint8) {
      input = _buildUint8Input(crop, th, tw, ch);
    } else {
      return null;
    }

    final oshape = outTensor.shape;
    final int timeSteps;
    final int classes;
    List<List<List<double>>> output3d;
    if (oshape.length == 3) {
      timeSteps = oshape[1];
      classes = oshape[2];
      output3d = List.generate(
        1,
        (_) => List.generate(
          timeSteps,
          (_) => List.generate(classes, (_) => 0.0),
        ),
      );
      interpreter.run(input, output3d);
    } else {
      timeSteps = oshape[0];
      classes = oshape[1];
      final output2d = List.generate(
        timeSteps,
        (_) => List.generate(classes, (_) => 0.0),
      );
      interpreter.run(input, output2d);
      output3d = [output2d];
    }

    final bestPath = List<int>.generate(timeSteps, (t) {
      var best = 0;
      var bestV = double.negativeInfinity;
      final row = output3d[0][t];
      for (var c = 0; c < classes; c++) {
        final v = row[c];
        if (v > bestV) {
          bestV = v;
          best = c;
        }
      }
      return best;
    });

    final text = _ctcGreedy(bestPath);
    final trimmed = text.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<List<List<List<double>>>> _buildFloatInput(
    img.Image crop,
    int th,
    int tw,
    int ch,
  ) {
    final out = List.generate(
      1,
      (_) => List.generate(
        th,
        (_) => List.generate(
          tw,
          (_) => List.filled(ch, 0.0),
        ),
      ),
    );
    for (var y = 0; y < th; y++) {
      for (var x = 0; x < tw; x++) {
        final p = crop.getPixel(x, y);
        if (ch == 1) {
          out[0][y][x][0] = p.luminance / 255.0;
        } else {
          out[0][y][x][0] = p.r / 255.0;
          out[0][y][x][1] = p.g / 255.0;
          out[0][y][x][2] = p.b / 255.0;
        }
      }
    }
    return out;
  }

  List<List<List<List<int>>>> _buildUint8Input(
    img.Image crop,
    int th,
    int tw,
    int ch,
  ) {
    final out = List.generate(
      1,
      (_) => List.generate(
        th,
        (_) => List.generate(
          tw,
          (_) => List.filled(ch, 0),
        ),
      ),
    );
    for (var y = 0; y < th; y++) {
      for (var x = 0; x < tw; x++) {
        final p = crop.getPixel(x, y);
        if (ch == 1) {
          out[0][y][x][0] = p.luminance.round().clamp(0, 255);
        } else {
          out[0][y][x][0] = p.r.toInt().clamp(0, 255);
          out[0][y][x][1] = p.g.toInt().clamp(0, 255);
          out[0][y][x][2] = p.b.toInt().clamp(0, 255);
        }
      }
    }
    return out;
  }

  String _ctcGreedy(List<int> bestPath) {
    final sb = StringBuffer();
    int? prev;
    for (final p in bestPath) {
      if (p == 0) {
        prev = p;
        continue;
      }
      if (prev == p) continue;
      final idx = p - 1;
      if (idx >= 0 && idx < _charset.length) {
        sb.write(_charset[idx]);
      }
      prev = p;
    }
    return sb.toString();
  }
}
