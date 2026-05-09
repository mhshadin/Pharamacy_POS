// Added OCR functionality for pharmacy inventory tracking
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/product.dart';
import 'strip_text_recognizer.dart';

typedef OcrCandidateFetcher = Future<List<Product>> Function(String ocrRegionText);

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

class OcrDebugRegion {
  final String text;
  final Rect? boundingBox;
  final bool removedByCleanup;
  final String? cleanupReason;
  final bool matched;
  final int? clusterId;
  final bool selectedInCluster;
  final bool suppressedInCluster;
  final double? sizeScore;
  final double? textScore;
  final double? hybridScore;
  final String? topProductName;
  final List<String> topOptions;

  const OcrDebugRegion({
    required this.text,
    required this.boundingBox,
    required this.removedByCleanup,
    this.cleanupReason,
    required this.matched,
    this.clusterId,
    required this.selectedInCluster,
    required this.suppressedInCluster,
    this.sizeScore,
    this.textScore,
    this.hybridScore,
    this.topProductName,
    this.topOptions = const [],
  });
}

class OcrDebugSummary {
  final int totalRawRegions;
  final int keptAfterCleanup;
  final int removedByCleanup;
  final int matchedRegions;
  final int exactCount;
  final int partialCount;
  final bool usedStripGrouping;
  final bool groupingReliable;
  final int clusterCount;
  final int suppressedInClusters;

  const OcrDebugSummary({
    required this.totalRawRegions,
    required this.keptAfterCleanup,
    required this.removedByCleanup,
    required this.matchedRegions,
    required this.exactCount,
    required this.partialCount,
    required this.usedStripGrouping,
    required this.groupingReliable,
    required this.clusterCount,
    required this.suppressedInClusters,
  });
}

class OcrDebugSnapshot {
  final Size? imageSize;
  final List<OcrDebugRegion> regions;
  final OcrDebugSummary summary;

  const OcrDebugSnapshot({
    required this.imageSize,
    required this.regions,
    required this.summary,
  });
}

class OcrProcessDebugResult {
  final List<OcrMatchResult> results;
  final OcrDebugSnapshot debug;

  const OcrProcessDebugResult({
    required this.results,
    required this.debug,
  });
}

class OcrService {
  static final _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );
  static const double _discardThreshold = 0.55;
  static const double _exactThreshold = 0.83;
  static const double _nameWeight = 1.0;
  static const double _genericWeight = 0.75;
  static const double _sizeWeight = 0.28;
  static const double _textWeight = 0.72;
  static const int _maxPartialOptions = 3;
  static const double _stripExpandXFactor = 0.35;
  static const double _stripExpandYFactor = 0.60;
  static const double _weakGroupingRatioThreshold = 0.30;

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

  /// ML Kit layout + optional per-crop ONNX/TFLite text; falls back to ML Kit strings.
  static Future<List<OcrTextRegion>> _enhanceRegionsWithStripAi(
    File imageFile,
    List<OcrTextRegion> mlkitRegions,
  ) async {
    if (mlkitRegions.isEmpty) return mlkitRegions;
    final recognizer = StripTextRecognizer.instance;
    if (!await recognizer.ensureLoaded()) return mlkitRegions;

    final clusters = _buildStripClusters(mlkitRegions);
    final useStripLayout = _isGroupingReliableForStripAi(
      clusters,
      mlkitRegions.length,
    );

    if (useStripLayout) {
      final boxes = <Rect>[];
      final clusterRefs = <_StripCluster>[];
      for (final cluster in clusters) {
        final u = _unionBounds(cluster.regions);
        if (u == null) continue;
        boxes.add(u);
        clusterRefs.add(cluster);
      }
      if (boxes.isEmpty) return mlkitRegions;
      final texts = await recognizer.readStripsFromFile(imageFile, boxes);
      final out = <OcrTextRegion>[];
      for (var i = 0; i < boxes.length; i++) {
        var text = texts[i];
        if (text == null || text.trim().isEmpty) {
          text = _fallbackMlKitText(clusterRefs[i].regions);
        }
        final trimmed = text.trim();
        if (trimmed.isEmpty) continue;
        out.add(OcrTextRegion(trimmed, boxes[i]));
      }
      return out.isEmpty ? mlkitRegions : out;
    }

    final indices = <int>[];
    final boxes = <Rect>[];
    for (var i = 0; i < mlkitRegions.length; i++) {
      final b = mlkitRegions[i].boundingBox;
      if (b == null) continue;
      indices.add(i);
      boxes.add(b);
    }
    if (boxes.isEmpty) return mlkitRegions;
    final texts = await recognizer.readStripsFromFile(imageFile, boxes);
    final out = List<OcrTextRegion>.from(mlkitRegions);
    for (var j = 0; j < indices.length; j++) {
      final i = indices[j];
      var t = texts[j];
      if (t == null || t.trim().isEmpty) t = mlkitRegions[i].text;
      out[i] = OcrTextRegion(t.trim(), mlkitRegions[i].boundingBox);
    }
    return out;
  }

  static Rect? _unionBounds(List<OcrTextRegion> regions) {
    Rect? u;
    for (final r in regions) {
      final b = r.boundingBox;
      if (b == null) continue;
      u = u == null ? b : u.expandToInclude(b);
    }
    return u;
  }

  static String _fallbackMlKitText(List<OcrTextRegion> regions) {
    return regions
        .map((e) => e.text)
        .where((t) => t.trim().isNotEmpty)
        .join(' ');
  }

  static bool _isGroupingReliableForStripAi(
    List<_StripCluster> clusters,
    int lineCount,
  ) {
    if (clusters.length <= 1) return false;
    if (lineCount <= 1) return false;
    final multiLineClusters =
        clusters.where((c) => c.regions.length > 1).length;
    final ratio = multiLineClusters / clusters.length;
    return ratio >= _weakGroupingRatioThreshold;
  }

  /// Main pipeline: extract → clean → match → crop each matched region.
  static Future<List<OcrMatchResult>> process(
    File imageFile,
    List<Product> products, {
    OcrCandidateFetcher? fetchCandidatesForOcr,
    bool useStripAiModel = false,
  }) async {
    var regions = await extractText(imageFile);
    if (useStripAiModel) {
      regions = await _enhanceRegionsWithStripAi(imageFile, regions);
    }
    final cleaned = _cleanRegions(regions);
    final matched = fetchCandidatesForOcr != null
        ? await _matchAgainstDbInternalAsync(
            cleaned,
            products,
            fetchCandidatesForOcr,
          )
        : _matchAgainstDbInternal(
            cleaned,
            (_) => products,
            debugAccumulator: null,
            fullRescoreIfNarrowedMiss: null,
          );
    return _attachCrops(imageFile, cleaned, matched);
  }

  static Future<OcrProcessDebugResult> processWithDebug(
    File imageFile,
    List<Product> products, {
    OcrCandidateFetcher? fetchCandidatesForOcr,
    bool useStripAiModel = false,
  }) async {
    var regions = await extractText(imageFile);
    if (useStripAiModel) {
      regions = await _enhanceRegionsWithStripAi(imageFile, regions);
    }
    final cleanedInfo = _cleanRegionsDetailed(regions);
    final debugAccumulator = _DebugAccumulator();
    final matched = fetchCandidatesForOcr != null
        ? await _matchAgainstDbInternalAsync(
            cleanedInfo.kept,
            products,
            fetchCandidatesForOcr,
            debugAccumulator: debugAccumulator,
          )
        : _matchAgainstDbInternal(
            cleanedInfo.kept,
            (_) => products,
            debugAccumulator: debugAccumulator,
            fullRescoreIfNarrowedMiss: null,
          );
    final withCrops = await _attachCrops(imageFile, cleanedInfo.kept, matched);

    final regionDebugByText = <String, _RegionDebug>{};
    for (final entry in debugAccumulator.regionByText.entries) {
      regionDebugByText[entry.key] = entry.value;
    }

    final debugRegions = <OcrDebugRegion>[];
    for (final kept in cleanedInfo.kept) {
      final info = regionDebugByText[kept.text];
      debugRegions.add(
        OcrDebugRegion(
          text: kept.text,
          boundingBox: kept.boundingBox,
          removedByCleanup: false,
          matched: info != null,
          clusterId: info?.clusterId,
          selectedInCluster: info?.selectedInCluster ?? false,
          suppressedInCluster: info?.suppressedInCluster ?? false,
          sizeScore: info?.sizeScore,
          textScore: info?.textScore,
          hybridScore: info?.hybridScore,
          topProductName: info?.topProductName,
          topOptions: info?.topOptions ?? const [],
        ),
      );
    }
    for (final removed in cleanedInfo.removed) {
      debugRegions.add(
        OcrDebugRegion(
          text: removed.region.text,
          boundingBox: removed.region.boundingBox,
          removedByCleanup: true,
          cleanupReason: removed.reason,
          matched: false,
          selectedInCluster: false,
          suppressedInCluster: false,
        ),
      );
    }

    final summary = OcrDebugSummary(
      totalRawRegions: regions.length,
      keptAfterCleanup: cleanedInfo.kept.length,
      removedByCleanup: cleanedInfo.removed.length,
      matchedRegions: debugRegions.where((r) => r.matched).length,
      exactCount: withCrops.where((r) => r.matchType == OcrMatchType.exact).length,
      partialCount:
          withCrops.where((r) => r.matchType == OcrMatchType.partial).length,
      usedStripGrouping: debugAccumulator.usedStripMode,
      groupingReliable: debugAccumulator.groupingReliable,
      clusterCount: debugAccumulator.clusterCount,
      suppressedInClusters: debugRegions.where((r) => r.suppressedInCluster).length,
    );

    return OcrProcessDebugResult(
      results: withCrops,
      debug: OcrDebugSnapshot(
        imageSize: await _readImageSize(imageFile),
        regions: debugRegions,
        summary: summary,
      ),
    );
  }

  static Future<List<OcrMatchResult>> _attachCrops(
    File imageFile,
    List<OcrTextRegion> cleaned,
    List<OcrMatchResult> matched,
  ) async {
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
    return _cleanRegionsDetailed(regions).kept;
  }

  static _CleanedRegions _cleanRegionsDetailed(List<OcrTextRegion> regions) {
    final kept = <OcrTextRegion>[];
    final removed = <_RemovedRegion>[];
    for (final region in regions) {
      final reason = _cleanupReason(region.text);
      if (reason == null) {
        kept.add(region);
      } else {
        removed.add(_RemovedRegion(region: region, reason: reason));
      }
    }
    return _CleanedRegions(kept: kept, removed: removed);
  }

  static String? _cleanupReason(String text) {
    final expiryPattern = RegExp(
      r'^(exp|expiry|mfg|mfd|batch|b\.no|lot|bd|tab|cap|inj|syp|susp|oint|gel|drops?|mg|ml|mcg|iu|%|rs\.?|tk\.?|\d+[\s./]\d+[\s./]?\d*)$',
      caseSensitive: false,
    );
    final pureNumber = RegExp(r'^\d[\d\s./,-]*$');
    final datePattern = RegExp(
      r'^\d{1,2}[/.-]\d{2,4}$|^\d{4}[/.-]\d{1,2}[/.-]\d{1,2}$',
    );

    final t = text.trim();
    if (t.length < 3) return 'too_short';
    if (pureNumber.hasMatch(t)) return 'pure_number';
    if (datePattern.hasMatch(t)) return 'date_pattern';
    if (expiryPattern.hasMatch(t)) return 'non_name_token';
    return null;
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
    return _matchAgainstDbInternal(
      regions,
      (_) => products,
      debugAccumulator: null,
      fullRescoreIfNarrowedMiss: null,
    );
  }

  static Future<List<OcrMatchResult>> _matchAgainstDbInternalAsync(
    List<OcrTextRegion> regions,
    List<Product> fullCatalog,
    OcrCandidateFetcher fetchCandidates, {
    _DebugAccumulator? debugAccumulator,
  }) async {
    if (regions.isEmpty || fullCatalog.isEmpty) return const [];
    final uniqueTexts = <String>{};
    for (final r in regions) {
      uniqueTexts.add(r.text);
    }
    final cache = <String, List<Product>>{};
    for (final text in uniqueTexts) {
      var list = await fetchCandidates(text);
      if (list.isEmpty) list = fullCatalog;
      cache[text] = list;
    }

    final regionCandidates = await _buildRegionCandidatesAsync(
      regions,
      (region) => cache[region.text] ?? fullCatalog,
      fullCatalog,
    );
    if (regionCandidates.isEmpty) return const [];

    final clusters = _buildStripClusters(regions);
    final useStripMode = _isGroupingReliable(clusters, regionCandidates.length);
    if (debugAccumulator != null) {
      debugAccumulator
        ..groupingReliable = useStripMode
        ..clusterCount = clusters.length;
      _populateDebugScores(regionCandidates, debugAccumulator);
      for (var i = 0; i < clusters.length; i++) {
        for (final r in clusters[i].regions) {
          debugAccumulator.regionByText.putIfAbsent(r.text, () => _RegionDebug());
          debugAccumulator.regionByText[r.text]!.clusterId = i;
        }
      }
    }

    if (!useStripMode) {
      if (debugAccumulator != null) debugAccumulator.usedStripMode = false;
      return _buildGlobalResults(regionCandidates);
    }
    if (debugAccumulator != null) debugAccumulator.usedStripMode = true;

    final candidateByText = <String, _RegionCandidate>{
      for (final c in regionCandidates) c.region.text: c,
    };
    final usedProducts = <String>{};
    final List<OcrMatchResult> results = [];

    for (final cluster in clusters) {
      _RegionCandidate? best;
      for (final region in cluster.regions) {
        final c = candidateByText[region.text];
        if (c == null) continue;
        if (best == null || c.hybridScore > best.hybridScore) {
          best = c;
        }
      }
      if (best == null) continue;
      if (debugAccumulator != null) {
        for (final region in cluster.regions) {
          final info = debugAccumulator.regionByText.putIfAbsent(
            region.text,
            () => _RegionDebug(),
          );
          if (region.text == best.region.text) {
            info.selectedInCluster = true;
          } else if (candidateByText.containsKey(region.text)) {
            info.suppressedInCluster = true;
          }
        }
      }

      final picked = _buildResultFromCandidate(best, usedProducts);
      if (picked != null) {
        results.add(picked);
      }
    }

    if (results.isEmpty) {
      return _buildGlobalResults(regionCandidates);
    }

    return results;
  }

  static Future<List<_RegionCandidate>> _buildRegionCandidatesAsync(
    List<OcrTextRegion> regions,
    List<Product> Function(OcrTextRegion region) productsForRegion,
    List<Product> fullCatalog,
  ) async {
    final maxHeight = regions
        .map((r) => r.boundingBox?.height ?? 0)
        .fold<double>(0, (prev, v) => v > prev ? v : prev);
    final maxArea = regions
        .map((r) => (r.boundingBox?.width ?? 0) * (r.boundingBox?.height ?? 0))
        .fold<double>(0, (prev, v) => v > prev ? v : prev);

    final productById = <String, Product>{for (final p in fullCatalog) p.id: p};
    final payloadRegions = <Map<String, Object?>>[];

    for (final region in regions) {
      final narrowed = productsForRegion(region);
      if (narrowed.isEmpty) continue;
      for (final p in narrowed) {
        productById[p.id] = p;
      }

      payloadRegions.add({
        'text': region.text,
        'width': region.boundingBox?.width ?? 0.0,
        'height': region.boundingBox?.height ?? 0.0,
        'products': narrowed
            .map(
              (p) => {
                'id': p.id,
                'name': p.name,
                'generic': p.generic,
              },
            )
            .toList(),
      });
    }
    if (payloadRegions.isEmpty) return const [];

    final payload = <String, Object?>{
      'regions': payloadRegions,
      'maxHeight': maxHeight,
      'maxArea': maxArea,
      'discardThreshold': _discardThreshold,
      'nameWeight': _nameWeight,
      'genericWeight': _genericWeight,
      'textWeight': _textWeight,
      'sizeWeight': _sizeWeight,
    };

    final scored = await Isolate.run(() => _scoreRegionsInIsolate(payload));

    final out = <_RegionCandidate>[];
    for (var i = 0; i < payloadRegions.length; i++) {
      final regionPayload = payloadRegions[i];
      final regionText = regionPayload['text'] as String;
      final region = regions.firstWhere((r) => r.text == regionText);
      final scoredRows = scored[i]['scores'] as List<dynamic>;
      if (scoredRows.isEmpty) {
        // Rescue path: only when narrowed set misses completely.
        final rescued = _scoreRegionAgainstProducts(
          region,
          fullCatalog,
          maxHeight,
          maxArea,
        );
        if (rescued.isEmpty) continue;
        out.add(
          _RegionCandidate(
            region: region,
            top: rescued.first,
            scoredProducts: rescued,
            sizeScore: _regionSizeScore(region, maxHeight, maxArea),
          ),
        );
        continue;
      }

      final regionScored = <_ScoredProduct>[];
      for (final row in scoredRows) {
        final map = row as Map<String, dynamic>;
        final id = map['id'] as String;
        final product = productById[id];
        if (product == null) continue;
        regionScored.add(
          _ScoredProduct(
            product: product,
            textScore: (map['textScore'] as num).toDouble(),
            hybridScore: (map['hybridScore'] as num).toDouble(),
          ),
        );
      }
      if (regionScored.isEmpty) continue;
      regionScored.sort((a, b) => b.hybridScore.compareTo(a.hybridScore));
      out.add(
        _RegionCandidate(
          region: region,
          top: regionScored.first,
          scoredProducts: regionScored,
          sizeScore: _regionSizeScore(region, maxHeight, maxArea),
        ),
      );
    }

    out.sort((a, b) => b.hybridScore.compareTo(a.hybridScore));
    return out;
  }

  static List<OcrMatchResult> _matchAgainstDbInternal(
    List<OcrTextRegion> regions,
    List<Product> Function(OcrTextRegion region) productsForRegion, {
    _DebugAccumulator? debugAccumulator,
    List<Product>? fullRescoreIfNarrowedMiss,
  }) {
    if (regions.isEmpty) return const [];
    var anyProducts = false;
    for (final r in regions) {
      if (productsForRegion(r).isNotEmpty) {
        anyProducts = true;
        break;
      }
    }
    if (!anyProducts) return const [];
    final regionCandidates = _buildRegionCandidates(
      regions,
      productsForRegion,
      fullRescoreIfNarrowedMiss,
    );
    if (regionCandidates.isEmpty) return const [];

    final clusters = _buildStripClusters(regions);
    final useStripMode = _isGroupingReliable(clusters, regionCandidates.length);
    if (debugAccumulator != null) {
      debugAccumulator
        ..groupingReliable = useStripMode
        ..clusterCount = clusters.length;
      _populateDebugScores(regionCandidates, debugAccumulator);
      for (var i = 0; i < clusters.length; i++) {
        for (final r in clusters[i].regions) {
          debugAccumulator.regionByText.putIfAbsent(r.text, () => _RegionDebug());
          debugAccumulator.regionByText[r.text]!.clusterId = i;
        }
      }
    }

    if (!useStripMode) {
      if (debugAccumulator != null) debugAccumulator.usedStripMode = false;
      return _buildGlobalResults(regionCandidates);
    }
    if (debugAccumulator != null) debugAccumulator.usedStripMode = true;

    final candidateByText = <String, _RegionCandidate>{
      for (final c in regionCandidates) c.region.text: c,
    };
    final usedProducts = <String>{};
    final List<OcrMatchResult> results = [];

    for (final cluster in clusters) {
      _RegionCandidate? best;
      for (final region in cluster.regions) {
        final c = candidateByText[region.text];
        if (c == null) continue;
        if (best == null || c.hybridScore > best.hybridScore) {
          best = c;
        }
      }
      if (best == null) continue;
      if (debugAccumulator != null) {
        for (final region in cluster.regions) {
          final info = debugAccumulator.regionByText.putIfAbsent(
            region.text,
            () => _RegionDebug(),
          );
          if (region.text == best.region.text) {
            info.selectedInCluster = true;
          } else if (candidateByText.containsKey(region.text)) {
            info.suppressedInCluster = true;
          }
        }
      }

      final picked = _buildResultFromCandidate(best, usedProducts);
      if (picked != null) {
        results.add(picked);
      }
    }

    if (results.isEmpty) {
      return _buildGlobalResults(regionCandidates);
    }

    return results;
  }

  static List<_ScoredProduct> _scoreRegionAgainstProducts(
    OcrTextRegion region,
    List<Product> products,
    double maxHeight,
    double maxArea,
  ) {
    final regionScored = <_ScoredProduct>[];
    for (final product in products) {
      final nameScore = _similarity(region.text, product.name) * _nameWeight;
      final genericScore =
          _similarity(region.text, product.generic) * _genericWeight;
      final textScore = nameScore > genericScore ? nameScore : genericScore;
      if (textScore < _discardThreshold) continue;

      final sizeScore = _regionSizeScore(region, maxHeight, maxArea);
      final hybridScore = ((textScore * _textWeight) + (sizeScore * _sizeWeight))
          .clamp(0.0, 1.0);
      regionScored.add(
        _ScoredProduct(
          product: product,
          textScore: textScore,
          hybridScore: hybridScore,
        ),
      );
    }
    regionScored.sort((a, b) => b.hybridScore.compareTo(a.hybridScore));
    return regionScored;
  }

  static List<_RegionCandidate> _buildRegionCandidates(
    List<OcrTextRegion> regions,
    List<Product> Function(OcrTextRegion region) productsForRegion,
    List<Product>? fullRescoreIfNarrowedMiss,
  ) {
    final maxHeight = regions
        .map((r) => r.boundingBox?.height ?? 0)
        .fold<double>(0, (prev, v) => v > prev ? v : prev);
    final maxArea = regions
        .map((r) => (r.boundingBox?.width ?? 0) * (r.boundingBox?.height ?? 0))
        .fold<double>(0, (prev, v) => v > prev ? v : prev);

    final out = <_RegionCandidate>[];
    for (final region in regions) {
      final narrowed = productsForRegion(region);
      if (narrowed.isEmpty) continue;

      var regionScored = _scoreRegionAgainstProducts(
        region,
        narrowed,
        maxHeight,
        maxArea,
      );
      if (regionScored.isEmpty &&
          fullRescoreIfNarrowedMiss != null &&
          narrowed.length < fullRescoreIfNarrowedMiss.length) {
        regionScored = _scoreRegionAgainstProducts(
          region,
          fullRescoreIfNarrowedMiss,
          maxHeight,
          maxArea,
        );
      }

      if (regionScored.isEmpty) continue;
      final top = regionScored.first;
      out.add(
        _RegionCandidate(
          region: region,
          top: top,
          scoredProducts: regionScored,
          sizeScore: _regionSizeScore(region, maxHeight, maxArea),
        ),
      );
    }
    out.sort((a, b) => b.hybridScore.compareTo(a.hybridScore));
    return out;
  }

  static double _regionSizeScore(
    OcrTextRegion region,
    double maxHeight,
    double maxArea,
  ) {
    final box = region.boundingBox;
    if (box == null || maxHeight <= 0 || maxArea <= 0) return 0.0;
    final hNorm = (box.height / maxHeight).clamp(0.0, 1.0);
    final aNorm = ((box.width * box.height) / maxArea).clamp(0.0, 1.0);
    return ((hNorm * 0.65) + (aNorm * 0.35)).clamp(0.0, 1.0);
  }

  static List<_StripCluster> _buildStripClusters(List<OcrTextRegion> regions) {
    final clusters = <_StripCluster>[];
    for (final region in regions) {
      final box = region.boundingBox;
      if (box == null) continue;
      final expanded = _expandRect(box);
      _StripCluster? hit;
      for (final cluster in clusters) {
        if (cluster.expandedBounds.overlaps(expanded)) {
          hit = cluster;
          break;
        }
      }
      if (hit == null) {
        clusters.add(_StripCluster(regions: [region], expandedBounds: expanded));
      } else {
        hit.regions.add(region);
        hit.expandedBounds = hit.expandedBounds.expandToInclude(expanded);
      }
    }

    // Merge chains that became adjacent after incremental expansion.
    var merged = true;
    while (merged) {
      merged = false;
      for (var i = 0; i < clusters.length; i++) {
        for (var j = i + 1; j < clusters.length; j++) {
          if (!clusters[i].expandedBounds.overlaps(clusters[j].expandedBounds)) {
            continue;
          }
          clusters[i].regions.addAll(clusters[j].regions);
          clusters[i].expandedBounds = clusters[i]
              .expandedBounds
              .expandToInclude(clusters[j].expandedBounds);
          clusters.removeAt(j);
          merged = true;
          break;
        }
        if (merged) break;
      }
    }

    return clusters;
  }

  static Rect _expandRect(Rect rect) {
    final dx = rect.width * _stripExpandXFactor;
    final dy = rect.height * _stripExpandYFactor;
    return Rect.fromLTRB(
      rect.left - dx,
      rect.top - dy,
      rect.right + dx,
      rect.bottom + dy,
    );
  }

  static bool _isGroupingReliable(
    List<_StripCluster> clusters,
    int candidateCount,
  ) {
    if (clusters.length <= 1) return false;
    if (candidateCount <= 1) return false;
    final multiLineClusters = clusters.where((c) => c.regions.length > 1).length;
    final ratio = multiLineClusters / clusters.length;
    return ratio >= _weakGroupingRatioThreshold;
  }

  static List<OcrMatchResult> _buildGlobalResults(
    List<_RegionCandidate> candidates,
  ) {
    final Set<String> matchedProductIds = {};
    final List<OcrMatchResult> results = [];

    for (final candidate in candidates) {
      final result = _buildResultFromCandidate(candidate, matchedProductIds);
      if (result != null) results.add(result);
    }

    return results;
  }

  static OcrMatchResult? _buildResultFromCandidate(
    _RegionCandidate candidate,
    Set<String> matchedProductIds,
  ) {
    if (matchedProductIds.contains(candidate.top.product.id)) return null;

    if (candidate.top.textScore >= _exactThreshold) {
      matchedProductIds.add(candidate.top.product.id);
      return OcrMatchResult(
        rawText: candidate.region.text,
        matchType: OcrMatchType.exact,
        exactProduct: candidate.top.product,
        matchScore: candidate.top.hybridScore,
        status: OcrStatus.accepted,
      );
    }

    final availableOptions = candidate.scoredProducts
        .take(_maxPartialOptions)
        .map((s) => s.product)
        .where((p) => !matchedProductIds.contains(p.id))
        .toList();
    if (availableOptions.isEmpty) return null;

    return OcrMatchResult(
      rawText: candidate.region.text,
      matchType: OcrMatchType.partial,
      partialOptions: availableOptions,
      matchScore: candidate.top.hybridScore,
      status: OcrStatus.pending,
    );
  }

  static void _populateDebugScores(
    List<_RegionCandidate> regionCandidates,
    _DebugAccumulator debugAccumulator,
  ) {
    for (final candidate in regionCandidates) {
      final topOptions = candidate.scoredProducts
          .take(_maxPartialOptions)
          .map((s) => s.product.name)
          .toList();
      debugAccumulator.regionByText[candidate.region.text] = _RegionDebug(
        textScore: candidate.top.textScore,
        hybridScore: candidate.top.hybridScore,
        sizeScore: candidate.sizeScore,
        topProductName: candidate.top.product.name,
        topOptions: topOptions,
      );
    }
  }

  static Future<Size?> _readImageSize(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final size = Size(
        frame.image.width.toDouble(),
        frame.image.height.toDouble(),
      );
      frame.image.dispose();
      return size;
    } catch (_) {
      return null;
    }
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
      final cropped = await recorder.endRecording().toImage(pw, ph);
      final bd = await cropped.toByteData(format: ui.ImageByteFormat.png);
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

    return ((bestTokenScore * 0.55) + (fullScore * 0.30) + containBonus).clamp(
      0.0,
      1.0,
    );
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
    final List<List<int>> dp = List.generate(
      m + 1,
      (_) => List.filled(n + 1, 0),
    );

    for (int i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        if (a[i - 1] == b[j - 1]) {
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          dp[i][j] =
              1 +
              [
                dp[i - 1][j],
                dp[i][j - 1],
                dp[i - 1][j - 1],
              ].reduce((x, y) => x < y ? x : y);
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
  final double textScore;
  final double hybridScore;
  _ScoredProduct({
    required this.product,
    required this.textScore,
    required this.hybridScore,
  });
}

class _RegionCandidate {
  final OcrTextRegion region;
  final _ScoredProduct top;
  final List<_ScoredProduct> scoredProducts;
  final double sizeScore;

  _RegionCandidate({
    required this.region,
    required this.top,
    required this.scoredProducts,
    required this.sizeScore,
  });

  double get hybridScore => top.hybridScore;
}

class _StripCluster {
  final List<OcrTextRegion> regions;
  Rect expandedBounds;

  _StripCluster({
    required this.regions,
    required this.expandedBounds,
  });
}

class _RemovedRegion {
  final OcrTextRegion region;
  final String reason;

  _RemovedRegion({required this.region, required this.reason});
}

class _CleanedRegions {
  final List<OcrTextRegion> kept;
  final List<_RemovedRegion> removed;

  _CleanedRegions({required this.kept, required this.removed});
}

class _DebugAccumulator {
  final Map<String, _RegionDebug> regionByText = {};
  bool usedStripMode = false;
  bool groupingReliable = false;
  int clusterCount = 0;
}

class _RegionDebug {
  int? clusterId;
  bool selectedInCluster;
  bool suppressedInCluster;
  double? sizeScore;
  double? textScore;
  double? hybridScore;
  String? topProductName;
  List<String> topOptions;

  _RegionDebug({
    this.sizeScore,
    this.textScore,
    this.hybridScore,
    this.topProductName,
    this.topOptions = const [],
  })  : selectedInCluster = false,
        suppressedInCluster = false;
}

List<Map<String, Object?>> _scoreRegionsInIsolate(Map<String, Object?> payload) {
  final regions = (payload['regions'] as List).cast<Map<String, Object?>>();
  final maxHeight = (payload['maxHeight'] as num).toDouble();
  final maxArea = (payload['maxArea'] as num).toDouble();
  final discardThreshold = (payload['discardThreshold'] as num).toDouble();
  final nameWeight = (payload['nameWeight'] as num).toDouble();
  final genericWeight = (payload['genericWeight'] as num).toDouble();
  final textWeight = (payload['textWeight'] as num).toDouble();
  final sizeWeight = (payload['sizeWeight'] as num).toDouble();

  final results = <Map<String, Object?>>[];
  for (final region in regions) {
    final text = (region['text'] as String).trim();
    final width = (region['width'] as num).toDouble();
    final height = (region['height'] as num).toDouble();
    final products = (region['products'] as List).cast<Map<String, Object?>>();

    final hNorm = maxHeight <= 0 ? 0.0 : (height / maxHeight).clamp(0.0, 1.0);
    final area = width * height;
    final aNorm = maxArea <= 0 ? 0.0 : (area / maxArea).clamp(0.0, 1.0);
    final sizeScore = ((hNorm * 0.65) + (aNorm * 0.35)).clamp(0.0, 1.0);

    final scores = <Map<String, Object?>>[];
    for (final p in products) {
      final id = p['id'] as String;
      final name = (p['name'] as String?) ?? '';
      final generic = (p['generic'] as String?) ?? '';

      final nameScore = _similarityIsolate(text, name) * nameWeight;
      final genericScore = _similarityIsolate(text, generic) * genericWeight;
      final textScore = nameScore > genericScore ? nameScore : genericScore;
      if (textScore < discardThreshold) continue;

      final hybridScore = ((textScore * textWeight) + (sizeScore * sizeWeight))
          .clamp(0.0, 1.0);
      scores.add({
        'id': id,
        'textScore': textScore,
        'hybridScore': hybridScore,
      });
    }

    scores.sort(
      (a, b) => ((b['hybridScore'] as num).toDouble())
          .compareTo((a['hybridScore'] as num).toDouble()),
    );
    results.add({'text': text, 'scores': scores});
  }
  return results;
}

double _similarityIsolate(String a, String b) {
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
      final ts = _levenshteinSimilarityIsolate(at, bt);
      if (ts > bestTokenScore) bestTokenScore = ts;
    }
  }

  final fullScore = _levenshteinSimilarityIsolate(aClean, bClean);
  double containBonus = 0.0;
  if (bClean.contains(aClean) || aClean.contains(bClean)) {
    containBonus = 0.15;
  }

  return ((bestTokenScore * 0.55) + (fullScore * 0.30) + containBonus).clamp(
    0.0,
    1.0,
  );
}

double _levenshteinSimilarityIsolate(String a, String b) {
  if (a == b) return 1.0;
  final dist = _levenshteinIsolate(a, b);
  final maxLen = a.length > b.length ? a.length : b.length;
  return 1.0 - (dist / maxLen);
}

int _levenshteinIsolate(String a, String b) {
  final m = a.length;
  final n = b.length;
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));

  for (var i = 0; i <= m; i++) {
    dp[i][0] = i;
  }
  for (var j = 0; j <= n; j++) {
    dp[0][j] = j;
  }

  for (var i = 1; i <= m; i++) {
    for (var j = 1; j <= n; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        dp[i][j] =
            1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]].reduce((x, y) {
                  return x < y ? x : y;
                });
      }
    }
  }
  return dp[m][n];
}
