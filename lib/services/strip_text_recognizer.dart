import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'strip_ai_model_store.dart';

/// On-device strip-crop text recognition: **OpenCV CRNN ONNX** (default) or CRNN-style TFLite.
class StripTextRecognizer {
  StripTextRecognizer._();
  static final StripTextRecognizer instance = StripTextRecognizer._();

  static const _charsetAsset = 'assets/strip_ai/ocr_charset.txt';

  /// OpenCV `blobFromImage` layout: NCHW [1, 1, 32, 100], float32, `(gray - 127.5) / 127.5`.
  static const List<int> _openCvEnInputShape = [1, 1, 32, 100];

  Interpreter? _interpreter;
  OrtSession? _ortSession;
  OrtSessionOptions? _ortSessionOptions;
  String? _ortInputName;

  List<String> _charset = [];
  String? _loadedPath;
  int _loadedMtimeMs = 0;

  List<String> get charset => _charset;

  void unload() {
    try {
      _interpreter?.close();
    } catch (_) {}
    _interpreter = null;
    try {
      _ortSession?.release();
    } catch (_) {}
    _ortSession = null;
    try {
      _ortSessionOptions?.release();
    } catch (_) {}
    _ortSessionOptions = null;
    _ortInputName = null;
    _loadedPath = null;
    _loadedMtimeMs = 0;
  }

  bool get _hasBackend => _interpreter != null || _ortSession != null;

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
    debugPrint('[StripAI] ensureLoaded path=${file.path} exists=${await file.exists()}');
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

    if (_hasBackend &&
        _loadedPath == file.path &&
        _loadedMtimeMs == mtimeMs) {
      debugPrint('[StripAI] ensureLoaded cache hit');
      return true;
    }

    unload();
    try {
      _charset = await _loadCharset();
      if (_charset.isEmpty) return false;

      final lower = file.path.toLowerCase();
      if (lower.endsWith('.onnx')) {
        final ok = _loadOnnx(file, mtimeMs);
        debugPrint('[StripAI] ONNX session ready=$ok');
        return ok;
      }
      final ok = _loadTflite(file, mtimeMs);
      debugPrint('[StripAI] TFLite interpreter ready=$ok');
      return ok;
    } catch (e, st) {
      debugPrint('StripTextRecognizer load failed: $e\n$st');
      unload();
      return false;
    }
  }

  bool _loadOnnx(File file, int mtimeMs) {
    final options = OrtSessionOptions();
    options.setIntraOpNumThreads(2);
    options.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    late OrtSession session;
    try {
      session = OrtSession.fromFile(file, options);
    } catch (_) {
      options.release();
      rethrow;
    }
    if (session.inputNames.isEmpty) {
      session.release();
      options.release();
      return false;
    }
    _ortSession = session;
    _ortSessionOptions = options;
    _ortInputName = session.inputNames.first;
    _loadedPath = file.path;
    _loadedMtimeMs = mtimeMs;
    return true;
  }

  bool _loadTflite(File file, int mtimeMs) {
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
        'StripTextRecognizer: TFLite classes $numClasses != charset+1 ${_charset.length + 1}',
      );
      interpreter.close();
      return false;
    }

    _interpreter = interpreter;
    _loadedPath = file.path;
    _loadedMtimeMs = mtimeMs;
    return true;
  }

  /// Runs recognition on each [boxes] crop; returns `null` entries when inference fails.
  Future<List<String?>> readStripsFromFile(
    File imageFile,
    List<Rect> boxes,
  ) async {
    if (!await ensureLoaded() || !_hasBackend || boxes.isEmpty) {
      debugPrint(
        '[StripAI] readStrips skip loaded=$_hasBackend boxes=${boxes.length}',
      );
      return List<String?>.filled(boxes.length, null);
    }

    debugPrint(
      '[StripAI] readStrips decode ${imageFile.path} boxes=${boxes.length} onnx=${_ortSession != null}',
    );
    final swDecode = Stopwatch()..start();
    final bytes = await imageFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    debugPrint('[StripAI] readStrips decode ${swDecode.elapsedMilliseconds}ms');
    if (decoded == null) return List<String?>.filled(boxes.length, null);

    final results = <String?>[];
    final swInfer = Stopwatch()..start();
    for (var i = 0; i < boxes.length; i++) {
      final box = boxes[i];
      final t0 = Stopwatch()..start();
      try {
        if (_ortSession != null) {
          results.add(_runOnnxCrop(decoded, box));
        } else {
          results.add(_runTfliteCrop(decoded, box));
        }
      } catch (_) {
        results.add(null);
      }
      final ms = t0.elapsedMilliseconds;
      if (boxes.length <= 20 || i == 0 || i == boxes.length - 1 || ms > 500) {
        debugPrint(
          '[StripAI] strip $i/${boxes.length} infer ${ms}ms out=${results.last}',
        );
      }
    }
    debugPrint(
      '[StripAI] readStrips total infer ${swInfer.elapsedMilliseconds}ms',
    );
    return results;
  }

  String? _runOnnxCrop(img.Image full, Rect box) {
    final session = _ortSession!;
    final inputName = _ortInputName!;

    final left = (box.left - 8).floor().clamp(0, full.width - 1);
    final top = (box.top - 4).floor().clamp(0, full.height - 1);
    final right = (box.right + 8).ceil().clamp(1, full.width);
    final bottom = (box.bottom + 4).ceil().clamp(1, full.height);
    final cw = (right - left).clamp(1, full.width);
    final chh = (bottom - top).clamp(1, full.height);

    var crop = img.copyCrop(full, x: left, y: top, width: cw, height: chh);
    crop = img.copyResize(crop, width: 100, height: 32);

    final buf = Float32List(1 * 1 * 32 * 100);
    var idx = 0;
    for (var y = 0; y < 32; y++) {
      for (var x = 0; x < 100; x++) {
        final p = crop.getPixel(x, y);
        final g = p.luminance.toDouble();
        buf[idx++] = (g - 127.5) / 127.5;
      }
    }

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      buf,
      _openCvEnInputShape,
    );
    final runOptions = OrtRunOptions();
    final List<OrtValue?> outputs;
    try {
      outputs = session.run(runOptions, {inputName: inputTensor});
    } finally {
      inputTensor.release();
      runOptions.release();
    }

    if (outputs.isEmpty) {
      for (final o in outputs) {
        o?.release();
      }
      return null;
    }

    try {
      final scores = _scoresFromOnnxOutput(outputs.first?.value);
      if (scores == null) return null;
      if (scores.isEmpty) return null;
      final classes = scores.first.length;
      if (classes != _charset.length + 1) {
        debugPrint(
          'StripTextRecognizer: ONNX row C=$classes != charset+1 ${_charset.length + 1}',
        );
        return null;
      }

      final bestPath = List<int>.generate(scores.length, (t) {
        var best = 0;
        var bestV = double.negativeInfinity;
        final row = scores[t];
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
    } finally {
      for (final o in outputs) {
        o?.release();
      }
    }
  }

  List<List<double>>? _scoresFromOnnxOutput(dynamic raw) {
    if (raw is List && raw.length == 1 && raw[0] is List) {
      return _scoresFromOnnxOutput(raw[0]);
    }
    if (raw is! List || raw.isEmpty) return null;
    final head = raw[0];
    if (head is List &&
        head.isNotEmpty &&
        head[0] is List &&
        (head[0] as List).isNotEmpty &&
        (head[0] as List)[0] is num) {
      final t = raw.length;
      return List.generate(t, (i) {
        final mid = (raw[i] as List)[0] as List;
        return mid.map((e) => (e as num).toDouble()).toList();
      });
    }
    if (head is List && head.isNotEmpty && head[0] is num) {
      return raw.map((row) {
        return (row as List).map((e) => (e as num).toDouble()).toList();
      }).toList();
    }
    return null;
  }

  String? _runTfliteCrop(img.Image full, Rect box) {
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
      input = _buildTfliteFloatInput(crop, th, tw, ch);
    } else if (inputType == TensorType.uint8) {
      input = _buildTfliteUint8Input(crop, th, tw, ch);
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

  List<List<List<List<double>>>> _buildTfliteFloatInput(
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

  List<List<List<List<int>>>> _buildTfliteUint8Input(
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
