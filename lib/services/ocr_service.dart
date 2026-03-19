// Added OCR functionality for pharmacy inventory tracking
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';

enum OcrMatchType { exact, partial }

enum OcrStatus { pending, accepted, rejected }

/// Carries a single ML Kit text line alongside its image bounding box.
class OcrTextRegion {
  final String text;
  final Rect? boundingBox;
  OcrTextRegion(this.text, this.boundingBox);
}

class OcrMatchResult {
  final String rawText;
  final OcrMatchType matchType;
  final Product? exactProduct;
  final List<Product> partialOptions;
  final double matchScore;
  final Uint8List? croppedBytes;
  Product? selectedProduct;
  OcrStatus status;

  OcrMatchResult({
    required this.rawText,
    required this.matchType,
    required this.matchScore,
    this.exactProduct,
    this.partialOptions = const [],
    this.croppedBytes,
    this.selectedProduct,
    this.status = OcrStatus.pending,
  });

  Product? get resolvedProduct => exactProduct ?? selectedProduct;

  OcrMatchResult copyWithCrop(Uint8List? bytes) => OcrMatchResult(
        rawText: rawText,
        matchType: matchType,
        matchScore: matchScore,
        exactProduct: exactProduct,
        partialOptions: partialOptions,
        croppedBytes: bytes,
        selectedProduct: selectedProduct,
        status: status,
      );
}

class OcrService {
  static final _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Extracts text regions (text + bounding box) from the image using ML Kit.
  static Future<List<OcrTextRegion>> extractText(File imageFile) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('OCR is only supported on Android and iOS.');
    }

    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await _textRecognizer.processImage(inputImage);

    final List<OcrTextRegion> results = [];
    for (final block in recognizedText.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        if (text.isNotEmpty) {
          final box = line.boundingBox;
          final flutterRect = Rect.fromLTRB(
            box.left.toDouble(),
            box.top.toDouble(),
            box.right.toDouble(),
            box.bottom.toDouble(),
          );
          results.add(OcrTextRegion(text, flutterRect));
        }
      }
    }
    return results;
  }

  /// Main pipeline: extract → clean → match → crop each matched region.
  static Future<List<OcrMatchResult>> process(
    File imageFile,
    List<Product> products,
  ) async {
    final regions = await extractText(imageFile);
    final cleaned = _cleanRegions(regions);
    final matched = matchAgainstDb(cleaned, products);

    // Crop image regions in parallel for performance.
    final futures = matched.map((result) async {
      final region = cleaned.firstWhere(
        (r) => r.text == result.rawText,
        orElse: () => OcrTextRegion(result.rawText, null),
      );
      if (region.boundingBox == null) return result;
      final bytes = await _cropRegion(imageFile, region.boundingBox!);
      return result.copyWithCrop(bytes);
    });

    return Future.wait(futures);
  }

  /// Removes noise tokens — pure numbers, dates, dosage labels, etc.
  static List<OcrTextRegion> _cleanRegions(List<OcrTextRegion> regions) {
    final expiryPattern = RegExp(
      r'^(exp|expiry|mfg|mfd|batch|b\.no|lot|bd|tab|cap|inj|syp|susp|oint|gel|drops?|mg|ml|mcg|iu|%|rs\.?|tk\.?|\d+[\s./]\d+[\s./]?\d*)$',
      caseSensitive: false,
    );
    final pureNumber = RegExp(r'^\d[\d\s./,-]*$');
    final datePattern = RegExp(
      r'^\d{1,2}[/.-]\d{2,4}$|^\d{4}[/.-]\d{1,2}[/.-]\d{1,2}$',
    );

    return regions.where((r) {
      final t = r.text.trim();
      if (t.length < 3) return false;
      if (pureNumber.hasMatch(t)) return false;
      if (datePattern.hasMatch(t)) return false;
      if (expiryPattern.hasMatch(t)) return false;
      return true;
    }).toList();
  }

  /// Matches OCR text regions against the product DB.
  /// - Name field match → full score
  /// - Generic field match → score × 0.75 (penalised to prevent duplicate cards)
  /// - Discard threshold: 0.55 (raised from 0.40)
  /// - Exact threshold: 0.80
  static List<OcrMatchResult> matchAgainstDb(
    List<OcrTextRegion> regions,
    List<Product> products,
  ) {
    final Set<String> matchedProductIds = {};
    final List<OcrMatchResult> results = [];

    for (final region in regions) {
      final text = region.text;
      final scoredProducts = <_ScoredProduct>[];

      for (final product in products) {
        final nameScore = _similarity(text, product.name);
        // Penalise generic-field matches to prevent duplicate cards when both
        // brand name and INN appear on the same strip.
        final genericScore = _similarity(text, product.generic) * 0.75;
        final bestScore = nameScore > genericScore ? nameScore : genericScore;
        if (bestScore >= 0.55) {
          scoredProducts.add(_ScoredProduct(product, bestScore));
        }
      }

      if (scoredProducts.isEmpty) continue;

      scoredProducts.sort((a, b) => b.score.compareTo(a.score));
      final top = scoredProducts.first;

      if (matchedProductIds.contains(top.product.id)) continue;

      if (top.score >= 0.80) {
        matchedProductIds.add(top.product.id);
        results.add(OcrMatchResult(
          rawText: text,
          matchType: OcrMatchType.exact,
          exactProduct: top.product,
          matchScore: top.score,
          status: OcrStatus.accepted,
        ));
      } else {
        final availableOptions = scoredProducts
            .take(3)
            .map((s) => s.product)
            .where((p) => !matchedProductIds.contains(p.id))
            .toList();
        if (availableOptions.isEmpty) continue;

        results.add(OcrMatchResult(
          rawText: text,
          matchType: OcrMatchType.partial,
          partialOptions: availableOptions,
          matchScore: top.score,
          status: OcrStatus.pending,
        ));
      }
    }

    return results;
  }

  /// Crops a rectangular region from the image file using dart:ui only.
  static Future<Uint8List?> _cropRegion(File imageFile, Rect box) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final src = frame.image;

      // Add a small horizontal padding so text isn't clipped at the edges.
      final paddedBox = Rect.fromLTRB(
        (box.left - 8).clamp(0.0, src.width.toDouble()),
        (box.top - 4).clamp(0.0, src.height.toDouble()),
        (box.right + 8).clamp(0.0, src.width.toDouble()),
        (box.bottom + 4).clamp(0.0, src.height.toDouble()),
      );
      final pw = paddedBox.width.toInt().clamp(1, src.width);
      final ph = paddedBox.height.toInt().clamp(1, src.height);

      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        src,
        paddedBox,
        Rect.fromLTWH(0, 0, pw.toDouble(), ph.toDouble()),
        Paint(),
      );
      final cropped =
          await recorder.endRecording().toImage(pw, ph);
      final bd =
          await cropped.toByteData(format: ui.ImageByteFormat.png);
      src.dispose();
      cropped.dispose();
      return bd?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  /// Normalized similarity score (0.0–1.0) combining token-level and
  /// full-string Levenshtein with a containment bonus.
  static double _similarity(String a, String b) {
    final aClean = a.toLowerCase().trim();
    final bClean = b.toLowerCase().trim();

    if (aClean == bClean) return 1.0;
    if (aClean.isEmpty || bClean.isEmpty) return 0.0;

    final aTokens = aClean.split(RegExp(r'[\s\-_/]+'));
    final bTokens = bClean.split(RegExp(r'[\s\-_/]+'));
    double bestTokenScore = 0.0;
    for (final at in aTokens) {
      if (at.length < 3) continue;
      for (final bt in bTokens) {
        if (bt.length < 3) continue;
        final ts = _levenshteinSimilarity(at, bt);
        if (ts > bestTokenScore) bestTokenScore = ts;
      }
    }

    final fullScore = _levenshteinSimilarity(aClean, bClean);

    double containBonus = 0.0;
    if (bClean.contains(aClean) || aClean.contains(bClean)) {
      containBonus = 0.15;
    }

    return ((bestTokenScore * 0.55) + (fullScore * 0.30) + containBonus)
        .clamp(0.0, 1.0);
  }

  static double _levenshteinSimilarity(String a, String b) {
    if (a == b) return 1.0;
    final dist = _levenshtein(a, b);
    final maxLen = a.length > b.length ? a.length : b.length;
    return 1.0 - (dist / maxLen);
  }

  static int _levenshtein(String a, String b) {
    final int m = a.length;
    final int n = b.length;
    final List<List<int>> dp =
        List.generate(m + 1, (_) => List.filled(n + 1, 0));

    for (int i = 0; i <= m; i++) { dp[i][0] = i; }
    for (int j = 0; j <= n; j++) { dp[0][j] = j; }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] = 1 +
              [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                  .reduce((x, y) => x < y ? x : y);
        }
      }
    }
    return dp[m][n];
  }

  static void dispose() {
    _textRecognizer.close();
  }
}

class _ScoredProduct {
  final Product product;
  final double score;
  _ScoredProduct(this.product, this.score);
}
