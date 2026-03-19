import 'dart:math';

import '../models/product.dart';

class ProductMatchScore {
  final Product product;
  final double score;

  const ProductMatchScore({required this.product, required this.score});
}

class ProductMatcher {
  /// Call once after loading products from the database.
  /// Stores the phonetic hash on each product so matching
  /// never recomputes it on every voice search.
  static void precomputeHashes(List<Product> products) {
    for (final p in products) {
      p.phoneticHash = _generatePhoneticHash(p.name);
    }
  }

  /// Returns the single best match above [minScore], or null.
  static ProductMatchScore? findBestMatch(
    String spokenText,
    List<Product> products, {
    double minScore = 0.65,
  }) {
    if (spokenText.trim().isEmpty || products.isEmpty) return null;

    final spokenHash = _generatePhoneticHash(spokenText);
    if (spokenHash.isEmpty) return null;

    Product? bestProduct;
    double bestScore = 0.0;

    for (final p in products) {
      final score = _scoreForProduct(spokenText, spokenHash, p);
      if (score > bestScore) {
        bestScore = score;
        bestProduct = p;
      }
    }

    if (bestProduct == null || bestScore < minScore) return null;

    return ProductMatchScore(product: bestProduct, score: bestScore);
  }

  /// Returns all products ranked by match score (highest first).
  static List<ProductMatchScore> rankMatches(
    String spokenText,
    List<Product> products,
  ) {
    if (spokenText.trim().isEmpty || products.isEmpty) return const [];

    final spokenHash = _generatePhoneticHash(spokenText);
    if (spokenHash.isEmpty) return const [];

    final scores = <ProductMatchScore>[];

    for (final p in products) {
      final score = _scoreForProduct(spokenText, spokenHash, p);
      if (score > 0) {
        scores.add(ProductMatchScore(product: p, score: score));
      }
    }

    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.take(5).toList();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  static double _scoreForProduct(
    String rawSpoken,
    String spokenHash,
    Product product,
  ) {
    final targetHash =
        product.phoneticHash ?? _generatePhoneticHash(product.name);

    if (targetHash.isEmpty) return 0.0;

    double similarity = _calculateSimilarity(spokenHash, targetHash);

    // Raw substring boost: if the stripped spoken text is contained in the
    // stripped product name (or vice versa), it's almost certainly a match.
    final rawSpokenStripped = rawSpoken.toLowerCase().replaceAll(' ', '');
    final rawProductStripped = product.name.toLowerCase().replaceAll(' ', '');

    if (rawProductStripped.contains(rawSpokenStripped)) {
      similarity = max(similarity, 0.90);
    }

    return similarity;
  }

  /// Pharmaceutical phonetic encoder.
  /// Converts a word to a consonant skeleton so that similar-sounding
  /// medicine names (with STT distortion) produce similar hashes.
  static String _generatePhoneticHash(String input) {
    if (input.isEmpty) return '';

    String s = input.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (s.isEmpty) return '';

    final firstChar = s[0];

    // Map visually/phonetically equivalent sounds.
    s = s.replaceAll('ph', 'f');
    s = s.replaceAll('x', 'ks');
    s = s.replaceAll('z', 's');
    s = s.replaceAll('c', 'k');
    s = s.replaceAll('v', 'b'); // South Asian v↔b drift

    // Strip vowels and weak consonants; keep hard consonants only.
    s = s.replaceAll(RegExp(r'[aeiouywh]'), '');

    // Restore the first character if it was stripped.
    if (s.isEmpty || s[0] != firstChar) {
      s = firstChar + s.replaceAll(firstChar, '');
    }

    // Collapse consecutive identical consonants (e.g. "ff" → "f").
    s = _dedup(s);

    return s;
  }

  static String _dedup(String str) {
    if (str.isEmpty) return str;
    final buf = StringBuffer()..write(str[0]);
    for (int i = 1; i < str.length; i++) {
      if (str[i] != str[i - 1]) buf.write(str[i]);
    }
    return buf.toString();
  }

  static double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    final distance = _levenshteinDistance(s1, s2);
    final maxLen = max(s1.length, s2.length);
    return 1.0 - (distance / maxLen);
  }

  static int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    var v0 = List<int>.generate(t.length + 1, (i) => i);
    final v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < s.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < t.length; j++) {
        final cost = s[i] == t[j] ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      final tmp = v0;
      v0 = List<int>.from(v1);
      v1.setAll(0, tmp);
    }
    return v0[t.length];
  }
}
